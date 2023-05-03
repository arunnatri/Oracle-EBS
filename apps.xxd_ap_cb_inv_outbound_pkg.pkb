--
-- XXD_AP_CB_INV_OUTBOUND_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:31:57 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_AP_CB_INV_OUTBOUND_PKG"
AS
    /***************************************************************************************
    * Program Name : XXDO_AP_CB_INV_OUTBOUND_PKG                                           *
    * Language     : PL/SQL                                                                *
    * Description  : Package to import the delivery success message  from Pager0           *
    *                                                                                      *
    * History      :                                                                       *
    *                                                                                      *
    * WHO          :       WHAT      Desc                                    WHEN          *
    * -------------- ----------------------------------------------------------------------*
    * Kishan Reddy         1.0       Initial Version                         16-JUN-2022   *
    * Kishan Reddy         1.1       CCR0010453 : File generation issue      08-FEB-2023   *
    * -------------------------------------------------------------------------------------*/

    gn_user_id        CONSTANT NUMBER := fnd_global.user_id;
    gn_login_id       CONSTANT NUMBER := fnd_global.login_id;
    gn_org_id         CONSTANT NUMBER := fnd_profile.VALUE ('ORG_ID');
    gn_resp_id        CONSTANT NUMBER := fnd_global.resp_id;
    gn_resp_appl_id   CONSTANT NUMBER := fnd_global.resp_appl_id;
    gn_request_id     CONSTANT NUMBER := fnd_global.conc_request_id;
    gv_def_mail_recips         do_mail_utils.tbl_recips;


    PROCEDURE print_log (pv_msg IN VARCHAR2, pv_time IN VARCHAR2 DEFAULT 'N')
    IS
        lv_proc_name    VARCHAR2 (30) := 'PRINT_LOG';
        lv_msg          VARCHAR2 (4000);
        lv_time_stamp   VARCHAR2 (20)
                            := TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS');
    BEGIN
        IF pv_time = 'Y'
        THEN
            lv_msg   := pv_msg || '. Timestamp: ' || lv_time_stamp;
        ELSE
            lv_msg   := pv_msg;
        END IF;

        IF gn_user_id = -1
        THEN
            DBMS_OUTPUT.put_line (lv_msg);
        ELSE
            fnd_file.put_line (fnd_file.LOG, lv_msg);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Unable to print log:' || SQLERRM);
    END print_log;

    ----
    --Write messages into output file
    --Parameters
    --PV_MSG        Message to be printed
    --PV_TIME       Print timestamp or not. Default is NO.
    PROCEDURE print_out (pv_msg IN VARCHAR2, pv_time IN VARCHAR2 DEFAULT 'N')
    IS
        lv_proc_name    VARCHAR2 (30) := 'PRINT_OUT';
        lv_msg          VARCHAR2 (4000);
        lv_time_stamp   VARCHAR2 (20)
                            := TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS');
    BEGIN
        IF pv_time = 'Y'
        THEN
            lv_msg   := pv_msg || '. Timestamp: ' || lv_time_stamp;
        ELSE
            lv_msg   := pv_msg;
        END IF;

        IF gn_user_id = -1
        THEN
            DBMS_OUTPUT.put_line (lv_msg);
        ELSE
            fnd_file.put_line (fnd_file.output, lv_msg);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Unable to print output:' || SQLERRM);
    END print_out;

    PROCEDURE add_error_message (p_invoice_id       IN NUMBER,
                                 p_invoice_number   IN VARCHAR2,
                                 p_invoice_date     IN DATE,
                                 p_error_code       IN VARCHAR2,
                                 p_error_message    IN VARCHAR2)
    IS
    BEGIN
        g_index                                := g_index + 1;
        g_error_tbl (g_index).invoice_id       := p_invoice_id;
        g_error_tbl (g_index).invoice_number   := p_invoice_number;
        g_error_tbl (g_index).invoice_date     := p_invoice_date;
        g_error_tbl (g_index).ERROR_CODE       := p_error_code;
        g_error_tbl (g_index).error_message    := p_error_message;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                ' Unexpected error in procedure add_error_message');
            fnd_file.put_line (
                fnd_file.LOG,
                'Error Message : ' || SUBSTR (SQLERRM, 1, 240));
    END add_error_message;

    PROCEDURE populate_errors_table
    IS
    BEGIN
        FORALL x IN g_error_tbl.FIRST .. g_error_tbl.LAST
            INSERT INTO XXDO.XXD_AP_INV_ERRORS_GT
                 VALUES g_error_tbl (x);
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Unexpected error in procedure populate_errors_table() ');
            fnd_file.put_line (
                fnd_file.LOG,
                'Error Message : ' || SUBSTR (SQLERRM, 1, 240));
    END populate_errors_table;


    FUNCTION remove_junk (p_input IN VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_output   VARCHAR2 (32767) := NULL;
    BEGIN
        IF p_input IS NOT NULL
        THEN
            SELECT REPLACE (REPLACE (REPLACE (REPLACE (REPLACE (p_input, CHR (9), ''), CHR (10), ''), '|', ' '), CHR (13), ''), ',', '')
              INTO lv_output
              FROM DUAL;
        ELSE
            RETURN NULL;
        END IF;

        RETURN lv_output;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END remove_junk;

    FUNCTION get_email_ids (pv_lookup_type VARCHAR2, pv_inst_name VARCHAR2)
        RETURN do_mail_utils.tbl_recips
    IS
        v_def_mail_recips   do_mail_utils.tbl_recips;

        CURSOR recips_cur IS
            SELECT xx.email_id
              FROM (SELECT flv.meaning email_id
                      FROM fnd_lookup_values flv
                     WHERE     1 = 1
                           AND flv.lookup_type = pv_lookup_type
                           AND flv.enabled_flag = 'Y'
                           AND flv.language = USERENV ('LANG')
                           AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                           NVL (
                                                               flv.start_date_active,
                                                               SYSDATE))
                                                   AND TRUNC (
                                                           NVL (
                                                               flv.end_date_active,
                                                               SYSDATE))) xx
             WHERE xx.email_id IS NOT NULL;

        CURSOR submitted_by_cur IS
            SELECT (fu.email_address) email_id
              FROM fnd_user fu
             WHERE     1 = 1
                   AND fu.user_id = gn_user_id
                   AND TRUNC (SYSDATE) BETWEEN fu.start_date
                                           AND TRUNC (
                                                   NVL (fu.end_date, SYSDATE));
    BEGIN
        -- fnd_file.put_line(fnd_file.log, 'Lookup Type:' || pv_lookup_type);
        v_def_mail_recips.DELETE;

        IF pv_inst_name = 'PRODUCTION'
        THEN
            FOR recips_rec IN recips_cur
            LOOP
                v_def_mail_recips (v_def_mail_recips.COUNT + 1)   :=
                    recips_rec.email_id;
            END LOOP;

            RETURN v_def_mail_recips;
        ELSE
            FOR submitted_by_rec IN submitted_by_cur
            LOOP
                v_def_mail_recips (v_def_mail_recips.COUNT + 1)   :=
                    submitted_by_rec.email_id;
            END LOOP;

            RETURN v_def_mail_recips;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            v_def_mail_recips (1)   := '';
            fnd_file.put_line (fnd_file.LOG,
                               'Failed to fetch email receipents');
            RETURN v_def_mail_recips;
    END get_email_ids;

    PROCEDURE get_le_details (pn_org_id                    IN     NUMBER,
                              xv_buyer_name                   OUT VARCHAR2,
                              xv_buyer_address_street         OUT VARCHAR2,
                              xv_buyer_address_post_code      OUT VARCHAR2,
                              xv_buyer_address_city           OUT VARCHAR2,
                              xv_buyer_address_province       OUT VARCHAR2,
                              xv_buyer_country_code           OUT VARCHAR2,
                              xv_buyer_vat_number             OUT VARCHAR2)
    AS
    BEGIN
        SELECT xep.name legal_entity_name, hl.address_line_1 le_address_street, hl.postal_code le_address_postal_code,
               hl.town_or_city le_address_city, hl.region_1 le_address_province, hl.country le_country_code,
               (hl.country || reg.registration_number) le_vat_number
          INTO xv_buyer_name, xv_buyer_address_street, xv_buyer_address_post_code, xv_buyer_address_city,
                            xv_buyer_address_province, xv_buyer_country_code, xv_buyer_vat_number
          FROM xle_registrations reg, xle_entity_profiles xep, hr_locations hl,
               hr_operating_units hou
         WHERE     xep.transacting_entity_flag = 'Y'
               AND xep.legal_entity_id = reg.source_id
               AND reg.source_table = 'XLE_ENTITY_PROFILES'
               AND reg.identifying_flag = 'Y'
               AND reg.location_id = hl.location_id
               AND xep.legal_entity_id = hou.default_legal_context_id
               AND hou.organization_id = pn_org_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_log ('Error in get_le_details :' || SQLERRM);
            xv_buyer_name                := NULL;
            xv_buyer_address_street      := NULL;
            xv_buyer_address_post_code   := NULL;
            xv_buyer_address_city        := NULL;
            xv_buyer_address_province    := NULL;
            xv_buyer_country_code        := NULL;
            xv_buyer_vat_number          := NULL;
    END get_le_details;

    PROCEDURE apply_hold_prc (pn_operating_unit   IN NUMBER,
                              pv_reprocess        IN VARCHAR2,
                              pv_invoice_number   IN NUMBER,
                              pv_from_date        IN VARCHAR2,
                              pv_to_date          IN VARCHAR2)
    AS
        CURSOR eligible_records_for_hold IS
              SELECT aia.invoice_num, apsa.invoice_id, assa.country,
                     aia.vendor_id, assa.vendor_site_id, supp.vendor_name,
                     aia.org_id, aia.invoice_date
                FROM ap_invoices_all aia, ap_payment_schedules_all apsa, ap_suppliers supp,
                     ap_supplier_sites_all assa
               WHERE     aia.invoice_id = apsa.invoice_id
                     AND aia.vendor_id = supp.vendor_id
                     AND aia.vendor_site_id = assa.vendor_site_id
                     AND supp.vendor_id = assa.vendor_id
                     AND aia.org_id = pn_operating_unit
                     AND NVL (apsa.hold_flag, 'N') <> 'Y'
                     AND NOT EXISTS
                             (SELECT 1
                                FROM xxdo.xxd_pgr_response_msgs_t inb
                               WHERE     inb.invoice_id = aia.invoice_id
                                     AND inb.invoice_type = 'AP_CB'
                                     AND inb.document_subtype IN
                                             ('DELIVERY_SUCCESS', 'DELIVERY_FAILURE'))
                     AND aia.invoice_id =
                         NVL (pv_invoice_number, aia.invoice_id)
                     AND aia.invoice_date BETWEEN pv_from_date AND pv_to_date
                     AND ap_invoices_pkg.get_posting_status (aia.invoice_id) =
                         'Y'
                     AND aia.source IN
                             (SELECT UNIQUE ffv.attribute2
                                FROM fnd_flex_value_sets ffvs, fnd_flex_values ffv
                               WHERE     ffvs.flex_value_Set_name =
                                         'XXD_AP_CB_EXTRACT_MAPPING'
                                     AND ffvs.flex_value_set_id =
                                         ffv.flex_value_set_id
                                     AND ffv.enabled_flag = 'Y')
                     AND NVL (assa.country, 'X') <> 'IT'
                     AND aia.payment_status_flag = 'N'
                     AND NVL (supp.num_1099, 'XX') NOT LIKE 'IT%'
            ORDER BY aia.invoice_num;

        ln_counter   NUMBER := 0;
    BEGIN
        FOR i IN eligible_records_for_hold
        LOOP
            IF ln_counter = 0
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Below invoices were applied payment hold : ');
                fnd_file.put_line (fnd_file.LOG,
                                   '=======================================');
            END IF;

            ln_counter   := ln_counter + 1;

            BEGIN
                INSERT INTO xxdo.xxd_ap_cb_inv_holds_t
                     VALUES (i.invoice_num, i.invoice_id, i.country,
                             i.vendor_id, i.vendor_site_id, i.vendor_name,
                             i.invoice_date, i.org_id, 'N',
                             'N', gn_user_id, SYSDATE,
                             gn_user_id, SYSDATE, gn_request_id);

                COMMIT;
                fnd_file.put_line (fnd_file.LOG, i.invoice_num);
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Failed to insert the data into Custom table:'
                        || SQLERRM);
            END;

            -- Apply the holds
            BEGIN
                UPDATE ap_payment_schedules_all
                   SET hold_flag = 'Y', last_updated_by = gn_user_id, last_update_date = SYSDATE
                 WHERE invoice_id = i.invoice_id AND hold_flag = 'N';

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Updating the ap_payment_schedules_all table is failed:'
                        || SQLERRM);
            END;

            -- Update the hold_flag in custom table
            BEGIN
                UPDATE xxdo.xxd_ap_cb_inv_holds_t
                   SET hold_applied = 'Y', last_updated_by = gn_user_id, last_update_date = SYSDATE
                 WHERE     invoice_id = i.invoice_id
                       AND NVL (hold_applied, 'N') = 'N';

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Updating the staging table is failed:' || SQLERRM);
            END;
        END LOOP;
    END apply_hold_prc;

    PROCEDURE release_holds_prc (pn_operating_unit   IN NUMBER,
                                 pv_reprocess        IN VARCHAR2,
                                 pv_invoice_number   IN NUMBER,
                                 pv_from_date        IN VARCHAR2,
                                 pv_to_date          IN VARCHAR2)
    AS
        CURSOR eligilbe_for_hold_release IS
            SELECT *
              FROM xxdo.xxd_ap_cb_inv_holds_t holds
             WHERE     NVL (holds.hold_applied, 'N') = 'Y'
                   AND NVL (holds.hold_released, 'N') = 'N'
                   AND EXISTS
                           (SELECT 1
                              FROM xxdo.xxd_pgr_response_msgs_t inb
                             WHERE     inb.invoice_id = holds.invoice_id
                                   AND inb.invoice_type = 'AP_CB'
                                   AND inb.document_subtype IN
                                           ('DELIVERY_SUCCESS', 'DELIVERY_FAILURE'))
                   AND holds.org_id = pn_operating_unit
                   AND holds.invoice_id =
                       NVL (pv_invoice_number, holds.invoice_id)
                   AND holds.invoice_date BETWEEN pv_from_date AND pv_to_date;
    BEGIN
        FOR i IN eligilbe_for_hold_release
        LOOP
            -- Release the holds
            BEGIN
                UPDATE ap_payment_schedules_all
                   SET hold_flag = 'N', last_updated_by = gn_login_id, last_update_date = SYSDATE
                 WHERE invoice_id = i.invoice_id AND hold_flag = 'Y';

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Updating the ap_payment_schedules_all table is failed:'
                        || SQLERRM);
            END;

            -- Update the hold_flag in custom table
            BEGIN
                UPDATE xxdo.xxd_ap_cb_inv_holds_t
                   SET hold_released = 'Y', last_updated_by = gn_login_id, last_update_date = SYSDATE
                 WHERE     invoice_id = i.invoice_id
                       AND NVL (hold_released, 'N') = 'N';

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Updating the staging table is failed:' || SQLERRM);
            END;
        END LOOP;
    END release_holds_prc;

    FUNCTION get_comp_segment (pn_invoice_id NUMBER, pn_invoice_line_num NUMBER, pn_org_id NUMBER)
        RETURN VARCHAR2
    IS
        lv_comp_segment   VARCHAR2 (10);
    BEGIN
        SELECT gcc.segment1
          INTO lv_comp_segment
          FROM ap_invoices_all aia, ap_invoice_lines_all aila, ap_invoice_distributions_all aida,
               gl_code_combinations gcc
         WHERE     aia.org_id = pn_org_id
               AND aia.invoice_id = pn_invoice_id
               AND aila.line_number = pn_invoice_line_num
               AND aia.invoice_id = aila.invoice_id
               AND aia.invoice_id = aida.invoice_id
               AND aila.invoice_id = aida.invoice_id
               AND aila.line_number = aida.invoice_line_number
               AND aida.dist_code_combination_id = gcc.code_combination_id
               AND aila.line_type_lookup_Code = 'ITEM';

        RETURN lv_comp_segment;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_log ('Unable to fetch the company segment ');
            lv_comp_segment   := '580';
            RETURN lv_comp_segment;
    END get_comp_segment;

    FUNCTION get_vat_rate (p_org_id        IN NUMBER,
                           p_invoice_id    IN NUMBER,
                           p_line_number   IN NUMBER)
        RETURN NUMBER
    IS
        ln_vat_rate   NUMBER;
        ln_tax_amt    NUMBER;
        ln_tax_cnt    NUMBER;
    BEGIN
        -- get tax rate count
        BEGIN
            SELECT COUNT (DISTINCT zl.tax_rate)
              INTO ln_tax_cnt
              FROM zx_lines zl
             WHERE     application_id = 200
                   AND zl.trx_id = p_invoice_id
                   AND zl.trx_line_number = p_line_number
                   AND zl.entity_code = 'AP_INVOICES'
                   AND zl.internal_organization_id = p_org_id
                   AND NVL (zl.cancel_flag, 'X') <> 'Y';
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_tax_cnt   := 0;
        END;

        IF ln_tax_cnt = 1
        THEN
              SELECT zl.tax_rate
                INTO ln_vat_rate
                FROM zx_lines zl
               WHERE     application_id = 200
                     AND zl.trx_id = p_invoice_id
                     AND zl.trx_line_number = p_line_number
                     AND zl.entity_code = 'AP_INVOICES'
                     AND zl.internal_organization_id = p_org_id
                     AND NVL (zl.cancel_flag, 'X') <> 'Y'
            GROUP BY zl.tax_rate;
        ELSIF ln_tax_cnt > 1
        THEN
              SELECT zl.tax_rate, SUM (zl.tax_amt)
                INTO ln_vat_rate, ln_tax_amt
                FROM zx_lines zl
               WHERE     application_id = 200
                     AND zl.trx_id = p_invoice_id
                     AND zl.trx_line_number = p_line_number
                     AND zl.entity_code = 'AP_INVOICES'
                     AND zl.internal_organization_id = p_org_id
                     AND NVL (zl.cancel_flag, 'X') <> 'Y'
            GROUP BY zl.tax_rate
              HAVING SUM (zl.tax_amt) > 0;
        ELSIF ln_tax_cnt = 0
        THEN
            ln_vat_rate   := 0;
        END IF;

        RETURN ln_vat_rate;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_log ('Error occured while fectching get_vat_rate  ');
            RETURN 0;
    END get_vat_rate;

    FUNCTION get_misc_amount (p_org_id IN NUMBER, p_invoice_id IN NUMBER)
        RETURN NUMBER
    IS
        ln_amount   NUMBER;
    BEGIN
        SELECT SUM (amount)
          INTO ln_amount
          FROM ap_invoice_lines_all
         WHERE     invoice_id = p_invoice_id
               AND org_id = p_org_id
               AND line_type_lookup_code = 'MISCELLANEOUS';

        RETURN ln_amount;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_log ('Error occured while fectching get_misc_amount  ');
            RETURN 0;
    END get_misc_amount;

    FUNCTION get_misc_tax_rate (p_org_id IN NUMBER, p_invoice_id IN NUMBER)
        RETURN NUMBER
    IS
        ln_rate   NUMBER;
    BEGIN
        SELECT SUM (zl.tax_rate)
          INTO ln_rate
          FROM ap_invoice_lines_all aila, zx_lines zl
         WHERE     aila.invoice_id = p_invoice_id
               AND aila.org_id = p_org_id
               AND aila.invoice_id = zl.trx_id
               AND zl.application_id = 200
               AND zl.trx_line_number = aila.line_number
               AND zl.tax_line_number = 1
               AND zl.internal_organization_id = aila.org_id
               AND aila.line_type_lookup_code = 'MISCELLANEOUS';

        RETURN ln_rate;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_log ('Error occured while fectching get_misc_amount  ');
            RETURN 0;
    END get_misc_tax_rate;

    FUNCTION get_vat_amount (p_org_id       IN NUMBER,
                             p_invoice_id   IN NUMBER,
                             p_tax_rate     IN NUMBER)
        RETURN NUMBER
    IS
        ln_vat_amount   NUMBER;
    BEGIN
        SELECT ABS (SUM (zx.tax_amt))
          INTO ln_vat_amount
          FROM zx_lines zx
         WHERE     zx.trx_id = p_invoice_id
               AND zx.entity_code = 'AP_INVOICES'
               AND zx.application_id = 200
               AND zx.tax_amt >= 0
               AND zx.internal_organization_id = p_org_id
               AND zx.tax_rate = p_tax_rate;

        RETURN ln_vat_amount;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_log ('Error occured while fectching get_vat_amount  ');
            RETURN 0;
    END get_vat_amount;

    FUNCTION get_vat_net_amount (p_org_id        IN NUMBER,
                                 p_invoice_id    IN NUMBER,
                                 p_line_number   IN NUMBER)
        RETURN NUMBER
    IS
        ln_vat_amount   NUMBER;
    BEGIN
        SELECT SUM (aila.amount)
          INTO ln_vat_amount
          FROM ap_invoice_lines_all aila, zx_lines zx
         WHERE     aila.invoice_id = p_invoice_id
               AND aila.invoice_id = zx.trx_id
               AND aila.line_number = zx.trx_line_number
               AND zx.entity_code = 'AP_INVOICES'
               AND zx.application_id = 200
               AND zx.tax_line_number = 1
               AND zx.trx_line_number = p_line_number
               AND zx.internal_organization_id = p_org_id
               AND aila.line_type_lookup_code = 'ITEM'
               AND zx.tax_rate IN
                       (SELECT zxl.tax_rate
                          FROM zx_lines zxl
                         WHERE     zxl.application_id = 200
                               AND zxl.trx_id = p_invoice_id
                               AND zxl.tax_line_number = 1
                               AND zxl.trx_line_number = p_line_number
                               AND zxl.internal_organization_id = p_org_id
                               AND zxl.entity_code = 'AP_INVOICES');


        RETURN ln_vat_amount;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_log ('Error occured while fectching get_vat_net_amount  ');
            RETURN 0;
    END get_vat_net_amount;

    FUNCTION get_document_type (p_org_id        IN NUMBER,
                                p_invoice_id    IN NUMBER,
                                p_line_number   IN NUMBER)
        RETURN VARCHAR2
    IS
        lv_doc_type   VARCHAR2 (30);
    BEGIN
        SELECT tag
          INTO lv_doc_type
          FROM fnd_lookup_values
         WHERE     language = 'US'
               AND ROWNUM = 1
               AND lookup_type = 'XXD_APCB_VT_TAX_CODE_MAPPING'
               AND lookup_Code =
                   (SELECT SUBSTR (tax_rate_code,
                                   1,
                                     INSTR (tax_rate_code, '_', -1
                                            , 1)
                                   - 1) tax_code
                      FROM zx_lines
                     WHERE     trx_id = p_invoice_id
                           AND trx_line_number = p_line_number
                           AND application_id = 200
                           AND internal_organization_id = p_org_id
                           AND entity_code = 'AP_INVOICES'
                           AND ROWNUM = 1);

        RETURN lv_doc_type;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_log ('Error occured while fectching get_document_type  ');
            RETURN NULL;
    END get_document_type;

    FUNCTION get_tax_code (p_org_id IN NUMBER, p_invoice_id IN NUMBER)
        RETURN VARCHAR2
    IS
        lv_tax_code   VARCHAR2 (100);
    BEGIN
        SELECT LISTAGG (SUBSTR (description, 1, (INSTR (description, ':') - 1)), ', ') WITHIN GROUP (ORDER BY description)
          INTO lv_tax_code
          FROM fnd_lookup_values
         WHERE     language = 'US'
               AND lookup_type = 'XXD_APCB_VT_TAX_CODE_MAPPING'
               AND lookup_Code IN
                       (SELECT SUBSTR (tax_rate_code,
                                       1,
                                         INSTR (tax_rate_code, '_', -1
                                                , 1)
                                       - 1) tax_code
                          FROM zx_lines
                         WHERE     trx_id = p_invoice_id
                               AND application_id = 200
                               AND internal_organization_id = p_org_id
                               AND tax_rate = 0
                               AND entity_code = 'AP_INVOICES');

        RETURN lv_tax_code;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_log (
                   'Error occured while fectching get_tax_code  '
                || p_invoice_id);
            RETURN NULL;
    END get_tax_code;

    FUNCTION get_tax_exempt_code (p_org_id        IN NUMBER,
                                  p_invoice_id    IN NUMBER,
                                  p_line_number   IN NUMBER)
        RETURN VARCHAR2
    IS
        lv_tax_code   VARCHAR2 (100);
    BEGIN
        SELECT LISTAGG (SUBSTR (description, 1, (INSTR (description, ':') - 1)), ', ') WITHIN GROUP (ORDER BY description)
          INTO lv_tax_code
          FROM fnd_lookup_values
         WHERE     language = 'US'
               AND ROWNUM = 1
               AND lookup_type = 'XXD_APCB_VT_TAX_CODE_MAPPING'
               AND lookup_Code =
                   (SELECT SUBSTR (tax_rate_code,
                                   1,
                                     INSTR (tax_rate_code, '_', -1
                                            , 1)
                                   - 1) tax_code
                      FROM zx_lines
                     WHERE     trx_id = p_invoice_id
                           AND trx_line_number = p_line_number
                           AND application_id = 200
                           AND internal_organization_id = p_org_id
                           AND entity_code = 'AP_INVOICES'
                           AND ROWNUM = 1);

        RETURN lv_tax_code;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_log (
                   'Error occured while fectching get_tax_exempt_code  '
                || p_invoice_id);
            RETURN NULL;
    END get_tax_exempt_code;

    FUNCTION get_routing_code (pv_company VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_routing_code   VARCHAR2 (30);
    BEGIN
        SELECT lookup_code
          INTO lv_routing_code
          FROM fnd_lookup_values
         WHERE     lookup_type = 'XXD_AP_CB_VT_ROUTING_CODE'
               AND language = 'US'
               AND meaning = 'AP_CB'
               AND tag = pv_company;

        RETURN lv_routing_code;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_log ('Unable to fetch the routing code ');
            RETURN 'VJ0HU3C';
    END get_routing_code;

    FUNCTION get_lookup_value (pv_column_name   IN VARCHAR2,
                               pv_company       IN VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_valid_flag   VARCHAR2 (10);
    BEGIN
        lv_valid_flag   := NULL;

        SELECT attribute3
          INTO lv_valid_flag
          FROM apps.fnd_lookup_values
         WHERE     1 = 1
               AND lookup_type = 'XXD_AP_CB_SEND_TO_SDI'
               AND enabled_flag = 'Y'
               AND SYSDATE BETWEEN NVL (start_date_active, SYSDATE)
                               AND NVL (end_date_active, SYSDATE)
               AND attribute_category = 'XXD_AP_CB_SEND_TO_SDI'
               AND attribute2 = pv_company
               AND attribute1 = pv_column_name
               AND language = 'US';

        RETURN lv_valid_flag;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_valid_flag   := NULL;

            RETURN lv_valid_flag;
    END get_lookup_value;

    FUNCTION get_tax_amount (p_org_id IN NUMBER, p_invoice_id IN NUMBER)
        RETURN NUMBER
    IS
        ln_tax_amount   NUMBER;
    BEGIN
        SELECT ABS (SUM (zl.tax_amt))
          INTO ln_tax_amount
          FROM zx_lines zl
         WHERE     application_id = 200
               AND zl.trx_id = p_invoice_id
               AND zl.tax_amt >= 0
               /*  AND zl.trx_line_number IN ( SELECT aila.line_number from ap_invoice_lines_all aila
                                              WHERE aila.line_type_lookup_code NOT IN ('MISCELLANEOUS','FREIGHT')
                                                AND aila.invoice_id = p_invoice_id
                                                AND aila.org_id = p_org_id)*/
               AND zl.entity_code = 'AP_INVOICES'
               AND zl.internal_organization_id = p_org_id;

        RETURN ln_tax_amount;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_log ('Error occured while fectching get_tax_amount  ');
            RETURN 0;
    END get_tax_amount;

    FUNCTION get_net_amount (p_org_id IN NUMBER, p_invoice_id IN NUMBER)
        RETURN NUMBER
    IS
        ln_net_amount   NUMBER;
    BEGIN
        SELECT SUM (aila.amount)
          INTO ln_net_amount
          FROM ap_invoice_lines_all aila
         WHERE     1 = 1
               AND aila.invoice_id = p_invoice_id
               AND aila.org_id = p_org_id
               AND aila.line_type_lookup_code = 'ITEM';

        RETURN ln_net_amount;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_log ('Error occured while fectching get_net_amount  ');
            RETURN 0;
    END get_net_amount;

    PROCEDURE generate_report_prc (p_conc_request_id IN NUMBER)
    IS
        CURSOR ap_msgs_cur IS
            SELECT DISTINCT invoice_number, invoice_id, invoice_date,
                            invoice_currency_code, conc_request_id, file_name
              FROM xxdo.xxd_ap_cb_inv_stg
             WHERE conc_request_id = p_conc_request_id AND process_flag = 'Y';

        CURSOR cur_inv_details (p_invoice_id         NUMBER,
                                pv_conc_request_id   NUMBER)
        IS
            SELECT (INVOICE_ID || '|' || INVOICE_NUMBER || '|' || INVOICE_DATE || '|' || PAYMENT_DUE_DATE || '|' || PAYMENT_TERM || '|' || INVOICE_CURRENCY_CODE || '|' || DOCUMENT_TYPE || '|' || ROUTING_CODE || '|' || INVOICE_DOC_REFERENCE || '|' || INV_DOC_REF_DESC || '|' || VENDOR_NAME || '|' || VENDOR_VAT_NUMBER || '|' || VENDOR_STREET || '|' || VENDOR_POST_CODE || '|' || VENDOR_ADDRESS_CITY || '|' || VENDOR_ADDRESS_COUNTRY || '|' || BUYER_NAME || '|' || BUYER_VAT_NUMBER || '|' || BUYER_ADDRESS_STREET || '|' || BUYER_ADDRESS_POSTAL_CODE || '|' || BUYER_ADDRESS_CITY || '|' || BUYER_ADDRESS_PROVINCE || '|' || BUYER_ADDRESS_COUNTRY_CODE || '|' || H_TOTAL_TAX_AMOUNT || '|' || H_TOTAL_NET_AMOUNT || '|' || H_TOTAL_NET_AMOUNT_INCLUDING_DISCOUNT_CHARGES || '|' || H_INVOICE_TOTAL || '|' || VAT_NET_AMOUNT || '|' || VAT_RATE || '|' || VAT_AMOUNT || '|' || TAX_CODE || '|' || INVOICE_LINE_DESCRIPTION || '|' || UNIT_OF_MEASURE_CODE || '|' || QUANTITY_INVOICED || '|' || UNIT_PRICE || '|' || L_TAX_RATE || '|' || L_TAX_EXEMPTION_CODE || '|' || L_NET_AMOUNT || '|' || H_CHARGE_AMOUNT || '|' || H_CHARGE_DESCRIPTION || '|' || H_CHARGE_TAX_RATE || '|' || EXCHANGE_RATE || '|' || EXCHANGE_DATE || '|' || ORIGINAL_CURRENCY_CODE) line
              FROM XXDO.XXD_AP_CB_INV_STG STG
             WHERE     1 = 1
                   AND conc_request_id = pv_conc_request_id
                   AND process_flag = 'Y'
                   AND invoice_id = p_invoice_id;

        CURSOR ap_failed_msgs_cur IS
              SELECT UNIQUE hdr.invoice_number, hdr.invoice_date, hdr.invoice_currency_code,
                            hdr.h_invoice_total, er.ERROR_CODE, er.error_message
                FROM xxdo.xxd_ap_cb_inv_stg hdr, xxdo.xxd_ap_inv_errors_gt er
               WHERE     hdr.conc_request_id = p_conc_request_id
                     AND hdr.invoice_id = er.invoice_id
                     AND hdr.conc_request_id = er.request_id
                     AND hdr.process_flag = 'E'
            ORDER BY hdr.invoice_number DESC;

        ln_rec_fail             NUMBER;
        ln_rec_total            NUMBER;
        ln_rec_success          NUMBER;
        lv_message              VARCHAR2 (32000);
        lv_recipients           VARCHAR2 (4000);
        lv_result               VARCHAR2 (100);
        lv_result_msg           VARCHAR2 (4000);
        lv_exc_directory_path   VARCHAR2 (1000);
        lv_exc_file_name        VARCHAR2 (1000);
        lv_mail_delimiter       VARCHAR2 (1) := '/';
        lv_inst_name            VARCHAR2 (30) := NULL;
        lv_msg                  VARCHAR2 (4000) := NULL;
        ln_ret_val              NUMBER := 0;
        lv_out_line             VARCHAR2 (4000);
        lv_error_message        VARCHAR2 (240);
        lv_error_reason         VARCHAR2 (240);
        lv_breif_err_resol      VARCHAR2 (240);
        lv_comments             VARCHAR2 (240);
        ln_counter              NUMBER;
        lv_line                 VARCHAR2 (32767) := NULL;

        ln_rec_fail_total       NUMBER;
    BEGIN
        ln_rec_fail      := 0;
        ln_rec_total     := 0;
        ln_rec_success   := 0;
        ln_counter       := 0;

        BEGIN
            SELECT COUNT (1)
              INTO ln_rec_total
              FROM xxdo.xxd_ap_cb_inv_stg
             WHERE conc_request_id = p_conc_request_id AND process_flag = 'Y';
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_rec_total   := 0;
        END;

        IF ln_rec_total <= 0
        THEN
            print_log ('There is nothing to Process...No File Exists.');
        ELSE
            BEGIN
                SELECT DECODE (applications_system_name, 'EBSPROD', 'PRODUCTION', 'TEST(' || applications_system_name || ')') applications_system_name
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

            gv_def_mail_recips   :=
                get_email_ids ('XXD_AP_INV_EMAIL_NOTIF_LKP', lv_inst_name);


            apps.do_mail_utils.send_mail_header ('erp@deckers.com', gv_def_mail_recips, 'Deckers AP Cross-Border Invoice Extract Report ' || ' Email generated from ' || lv_inst_name || ' instance'
                                                 , ln_ret_val);

            do_mail_utils.send_mail_line (
                'Content-Type: multipart/mixed; boundary=boundarystring',
                ln_ret_val);
            do_mail_utils.send_mail_line ('', ln_ret_val);
            do_mail_utils.send_mail_line ('--boundarystring', ln_ret_val);
            do_mail_utils.send_mail_line ('', ln_ret_val);
            do_mail_utils.send_mail_line ('Hello Team', ln_ret_val);
            do_mail_utils.send_mail_line ('  ', ln_ret_val);
            do_mail_utils.send_mail_line (
                'Please see attached Deckers AP Cross-Border Invoice Extract Report.',
                ln_ret_val);
            do_mail_utils.send_mail_line ('', ln_ret_val);
            do_mail_utils.send_mail_line (
                'Note: This is auto generated mail, please donot reply.',
                ln_ret_val);
            -- mail attachement

            lv_line   :=
                   'INVOICE_ID'
                || '|'
                || 'INVOICE_NUMBER'
                || '|'
                || 'INVOICE_DATE'
                || '|'
                || 'PAYMENT_DUE_DATE'
                || '|'
                || 'PAYMENT_TERM'
                || '|'
                || 'INVOICE_CURRENCY_CODE'
                || '|'
                || 'DOCUMENT_TYPE'
                || '|'
                || 'ROUTING_CODE'
                || '|'
                || 'INVOICE_DOC_REFERENCE'
                || '|'
                || 'INV_DOC_REF_DESC'
                || '|'
                || 'VENDOR_NAME'
                || '|'
                || 'VENDOR_VAT_NUMBER'
                || '|'
                || 'VENDOR_STREET'
                || '|'
                || 'VENDOR_POST_CODE'
                || '|'
                || 'VENDOR_ADDRESS_CITY'
                || '|'
                || 'VENDOR_ADDRESS_COUNTRY'
                || '|'
                || 'BUYER_NAME'
                || '|'
                || 'BUYER_VAT_NUMBER'
                || '|'
                || 'BUYER_ADDRESS_STREET'
                || '|'
                || 'BUYER_ADDRESS_POSTAL_CODE'
                || '|'
                || 'BUYER_ADDRESS_CITY'
                || '|'
                || 'BUYER_ADDRESS_PROVINCE'
                || '|'
                || 'BUYER_ADDRESS_COUNTRY_CODE'
                || '|'
                || 'H_TOTAL_TAX_AMOUNT'
                || '|'
                || 'H_TOTAL_NET_AMOUNT'
                || '|'
                || 'H_TOTAL_NET_AMOUNT_INCLUDING_DISCOUNT_CHARGES'
                || '|'
                || 'H_INVOICE_TOTAL'
                || '|'
                || 'VAT_NET_AMOUNT'
                || '|'
                || 'VAT_RATE'
                || '|'
                || 'VAT_AMOUNT'
                || '|'
                || 'TAX_CODE'
                || '|'
                || 'INVOICE_LINE_DESCRIPTION'
                || '|'
                || 'UNIT_OF_MEASURE_CODE'
                || '|'
                || 'QUANTITY_INVOICED'
                || '|'
                || 'UNIT_PRICE'
                || '|'
                || 'L_TAX_RATE'
                || '|'
                || 'L_TAX_EXEMPTION_CODE'
                || '|'
                || 'L_NET_AMOUNT'
                || '|'
                || 'H_CHARGE_AMOUNT'
                || '|'
                || 'H_CHARGE_DESCRIPTION'
                || '|'
                || 'H_CHARGE_TAX_RATE'
                || '|'
                || 'EXCHANGE_RATE'
                || '|'
                || 'EXCHANGE_DATE'
                || '|'
                || 'ORIGINAL_CURRENCY_CODE';

            FOR i IN ap_msgs_cur
            LOOP
                ln_counter   := ln_counter + 1;

                do_mail_utils.send_mail_line ('--boundarystring', ln_ret_val);
                do_mail_utils.send_mail_line ('Content-Type: text/xls',
                                              ln_ret_val);
                do_mail_utils.send_mail_line (
                    'Content-Disposition: attachment; filename="' || i.file_name,
                    ln_ret_val);

                apps.do_mail_utils.send_mail_line (lv_message, ln_ret_val);


                apps.do_mail_utils.send_mail_line (lv_line, ln_ret_val);

                FOR j IN cur_inv_details (i.invoice_id, i.conc_request_id)
                LOOP
                    apps.do_mail_utils.send_mail_line (j.line, ln_ret_val);
                END LOOP;
            END LOOP;

            apps.do_mail_utils.send_mail_close (ln_ret_val);
            print_log ('lv_ result is - ' || lv_result);
            print_log ('lv_result_msg is - ' || lv_result_msg);
        END IF;

        -- sending error invoices report

        BEGIN
            SELECT COUNT (1)
              INTO ln_rec_fail_total
              FROM xxdo.xxd_ap_cb_inv_stg
             WHERE conc_request_id = p_conc_request_id AND process_flag = 'E';
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_rec_fail_total   := 0;
        END;

        IF ln_rec_fail_total <= 0
        THEN
            print_log ('There is nothing to Process...No File Exists.');
        ELSE
            BEGIN
                SELECT DECODE (applications_system_name, 'EBSPROD', 'PRODUCTION', 'TEST(' || applications_system_name || ')') applications_system_name
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

            gv_def_mail_recips   :=
                get_email_ids ('XXD_AP_INV_ERR_EMAIL_NOTIF_LKP',
                               lv_inst_name);


            apps.do_mail_utils.send_mail_header ('erp@deckers.com', gv_def_mail_recips, 'Deckers AP Cross-Border Invoice Error Report ' || ' Email generated from ' || lv_inst_name || ' instance'
                                                 , ln_ret_val);

            do_mail_utils.send_mail_line (
                'Content-Type: multipart/mixed; boundary=boundarystring',
                ln_ret_val);
            do_mail_utils.send_mail_line ('', ln_ret_val);
            do_mail_utils.send_mail_line ('--boundarystring', ln_ret_val);
            do_mail_utils.send_mail_line ('', ln_ret_val);
            do_mail_utils.send_mail_line ('Hello Team', ln_ret_val);
            do_mail_utils.send_mail_line ('  ', ln_ret_val);
            do_mail_utils.send_mail_line (
                'Please see attached Deckers AP Cross-Border Invoice Error Report.',
                ln_ret_val);
            do_mail_utils.send_mail_line ('', ln_ret_val);
            do_mail_utils.send_mail_line (
                'Note: This is auto generated mail, please donot reply.',
                ln_ret_val);
            do_mail_utils.send_mail_line ('--boundarystring', ln_ret_val);
            do_mail_utils.send_mail_line ('Content-Type: text/xls',
                                          ln_ret_val);
            do_mail_utils.send_mail_line (
                   'Content-Disposition: attachment; filename="Deckers_AP_Cross_Border_error_'
                || TO_CHAR (SYSDATE, 'RRRRMMDD_HH24MISS')
                || '.xls"',
                ln_ret_val);
            apps.do_mail_utils.send_mail_line (lv_message, ln_ret_val);
            apps.do_mail_utils.send_mail_line (
                   'Sr No'
                || CHR (9)
                || 'Invoice Number'
                || CHR (9)
                || 'Invoice Date'
                || CHR (9)
                || 'Error Code'
                || CHR (9)
                || 'Error Message'
                || CHR (9)
                || 'Error Reason'
                || CHR (9)
                || 'Brief Resolution'
                || CHR (9)
                || 'Comments'
                || CHR (9),
                ln_ret_val);
            ln_counter   := 0;

            FOR r_line IN ap_failed_msgs_cur
            LOOP
                ln_counter   := ln_counter + 1;

                -- to get error message details
                BEGIN
                    SELECT ffv.description error_message, attribute1 error_reason, attribute2 breif_error_resolution,
                           attribute3 comments
                      INTO lv_error_message, lv_error_reason, lv_breif_err_resol, lv_comments
                      FROM fnd_flex_value_sets ffvs, fnd_flex_values_vl ffv
                     WHERE     ffvs.flex_value_set_id = ffv.flex_value_set_id
                           AND ffvs.flex_value_set_name =
                               'XXD_AP_INV_ERROR_MESSAGES_VS'
                           AND ffv.enabled_flag = 'Y'
                           AND ffv.flex_value = r_line.ERROR_CODE;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        print_log ('Failed to get the error details ');
                        lv_error_message     := NULL;
                        lv_error_reason      := NULL;
                        lv_breif_err_resol   := NULL;
                        lv_comments          := NULL;
                END;


                apps.do_mail_utils.send_mail_line (
                       ln_counter
                    || CHR (9)
                    || r_line.invoice_number
                    || CHR (9)
                    || r_line.invoice_Date
                    || CHR (9)
                    || r_line.ERROR_CODE
                    || CHR (9)
                    || NVL (lv_error_message, r_line.error_message)
                    || CHR (9)
                    || lv_error_reason
                    || CHR (9)
                    || lv_breif_err_resol
                    || CHR (9)
                    || lv_comments
                    || CHR (9),
                    ln_ret_val);
            --apps.do_mail_utils.send_mail_line(lv_out_line, lv_message);
            END LOOP;

            apps.do_mail_utils.send_mail_close (ln_ret_val);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_log ('Error :' || SQLERRM);
    END generate_report_prc;

    PROCEDURE insert_ap_eligible_recs (pv_operating_unit IN VARCHAR2, pv_reprocess IN VARCHAR2, pv_invoice_num IN NUMBER, pv_from_date IN VARCHAR2, pv_to_date IN VARCHAR2, x_ret_code OUT VARCHAR2
                                       , x_ret_message OUT VARCHAR2)
    IS
        CURSOR cur_inv (p_org_id IN NUMBER, p_invoice_id IN NUMBER, p_invoice_from_date IN VARCHAR2
                        , p_invoice_to_date IN VARCHAR2)
        IS
            SELECT aia.invoice_id,
                   aia.invoice_num
                       invoice_number,
                   aia.invoice_date,
                   aia.invoice_currency_code,
                   aia.exchange_rate,
                   aia.exchange_date,
                   aia.invoice_type_lookup_code,
                   aia.vendor_id,
                   apsa.due_date
                       payment_due_date,
                   apt.name
                       payment_term,
                   get_document_type (aia.org_id,
                                      aia.invoice_id,
                                      aila.line_number)
                       document_type,
                   get_routing_code (
                       get_comp_segment (aia.invoice_id,
                                         aila.line_number,
                                         aia.org_id))
                       routing_code,
                   DECODE (aia.invoice_type_lookup_code,
                           'CREDIT', aia.attribute6,
                           NULL)
                       invoice_doc_reference,
                   DECODE (
                       aia.invoice_type_lookup_code,
                       'CREDIT', (SELECT description
                                    FROM ap_invoices_all ai
                                   WHERE     ai.invoice_num = aia.attribute6
                                         AND ROWNUM = 1),
                       NULL)
                       inv_doc_ref_desc,
                   aps.vendor_name
                       vendor_name,
                   aps.num_1099
                       vendor_vat_number,
                   aps.vat_registration_num,
                   apss.address_line1
                       vendor_street,
                   apss.zip
                       vendor_post_code,
                   apss.city
                       vendor_address_city,
                   apss.country
                       vendor_address_country,
                   get_tax_amount (aia.org_id, aia.invoice_id)
                       h_total_tax_amount,
                   get_net_amount (aia.org_id, aia.invoice_id)
                       h_total_net_amount,
                   (SELECT SUM (NVL (line.amount, 0))
                      FROM ap_invoice_lines_all line
                     WHERE     line.org_id = aia.org_id
                           AND line.invoice_id = aia.invoice_id
                           AND line.line_type_lookup_code <> 'TAX')
                       h_total_net_amount_including_discount_charges,
                   aia.invoice_amount
                       h_invoice_total,
                   NVL (aila.description, aia.invoice_num)
                       invoice_line_description,
                   NVL (aila.unit_meas_lookup_code, 'EA')
                       unit_of_measure_code,
                   NVL (aila.quantity_invoiced, 1)
                       quantity_invoiced,
                   NVL (aila.unit_price, aila.amount)
                       unit_price,
                   get_tax_exempt_code (aia.org_id,
                                        aia.invoice_id,
                                        aila.line_number)
                       l_tax_exemption_code,
                   get_tax_code (aia.org_id, aia.invoice_id)
                       tax_code,
                   aila.amount,
                   aila.amount
                       l_net_amount/*  ,(select sum(NVL(line.amount,0)) from ap_invoice_lines_all line
                                       where line.org_id =aia.org_id
                                       and line.invoice_id = aia.invoice_id
                                       and line.line_number = aila.line_number
                                       and line.line_type_lookup_code <> 'TAX') l_net_amount*/
                                   ,
                   get_vat_rate (aia.org_id,
                                 aia.invoice_id,
                                 aila.line_number)
                       vat_rate-- ,get_vat_amount(aia.org_id,aia.invoice_id,aila.line_number) vat_amount
                               -- ,get_vat_net_amount(aia.org_id,aia.invoice_id,aila.line_number) vat_net_amount
                               ,
                   aia.org_id,
                   aia.set_of_books_id,
                   get_comp_segment (aia.invoice_id,
                                     aila.line_number,
                                     aia.org_id)
                       company,
                   get_misc_amount (aia.org_id, aia.invoice_id)
                       h_charge_amount,
                   get_misc_tax_rate (aia.org_id, aia.invoice_id)
                       h_charge_tax_rate
              FROM ap_invoices_all aia, ap_invoice_lines_all aila, ap_payment_schedules_all apsa,
                   ap_suppliers aps, ap_supplier_sites_all apss, ap_terms apt
             WHERE     aia.invoice_id = aila.invoice_id
                   AND aia.invoice_id = apsa.invoice_id
                   AND apsa.hold_flag = 'Y'
                   AND aia.vendor_id = aps.vendor_id
                   AND aps.vendor_id = apss.vendor_id
                   AND aia.vendor_site_id = apss.vendor_site_id
                   AND aia.terms_id = apt.term_id
                   AND NOT EXISTS
                           (SELECT 1
                              FROM XXD_AP_CB_INV_STG stg
                             WHERE     stg.invoice_id = aia.invoice_id
                                   AND stg.process_flag = 'Y')
                   AND aia.org_id = p_org_id
                   AND aia.invoice_id = NVL (p_invoice_id, aia.invoice_id)
                   AND aia.invoice_date BETWEEN p_invoice_from_date
                                            AND p_invoice_to_date
                   AND ap_invoices_pkg.get_posting_status (aia.invoice_id) =
                       'Y'
                   AND aia.source IN
                           (SELECT UNIQUE ffv.attribute2
                              FROM fnd_flex_value_sets ffvs, fnd_flex_values ffv
                             WHERE     ffvs.flex_value_Set_name =
                                       'XXD_AP_CB_EXTRACT_MAPPING'
                                   AND ffvs.flex_value_set_id =
                                       ffv.flex_value_set_id
                                   AND ffv.enabled_flag = 'Y')
                   AND aila.line_type_lookup_code = 'ITEM'
                   AND aila.discarded_flag = 'N'
                   AND NVL (aps.num_1099, 'XX') NOT LIKE 'IT%'
                   AND NVL (apss.country, 'XX') <> 'IT';

        CURSOR cur_reprocess (p_org_id IN NUMBER, p_invoice_id IN NUMBER, p_invoice_from_date IN VARCHAR2
                              , p_invoice_to_date IN VARCHAR2)
        IS
            SELECT aia.invoice_id,
                   aia.invoice_num
                       invoice_number,
                   aia.invoice_date,
                   aia.invoice_currency_code,
                   aia.exchange_rate,
                   aia.exchange_date,
                   apsa.due_date
                       payment_due_date,
                   apt.name
                       payment_term,
                   aia.vendor_id,
                   aia.invoice_type_lookup_code,
                   get_document_type (aia.org_id,
                                      aia.invoice_id,
                                      aila.line_number)
                       document_type,
                   get_routing_code (
                       get_comp_segment (aia.invoice_id,
                                         aila.line_number,
                                         aia.org_id))
                       routing_code,
                   DECODE (aia.invoice_type_lookup_code,
                           'CREDIT', aia.attribute6,
                           NULL)
                       invoice_doc_reference,
                   DECODE (
                       aia.invoice_type_lookup_code,
                       'CREDIT', (SELECT description
                                    FROM ap_invoices_all ai
                                   WHERE     ai.invoice_num = aia.attribute6
                                         AND ROWNUM = 1),
                       NULL)
                       inv_doc_ref_desc,
                   aps.vendor_name
                       vendor_name,
                   aps.num_1099
                       vendor_vat_number,
                   aps.vat_registration_num,
                   apss.address_line1
                       vendor_street,
                   apss.zip
                       vendor_post_code,
                   apss.city
                       vendor_address_city,
                   apss.country
                       vendor_address_country,
                   get_tax_amount (aia.org_id, aia.invoice_id)
                       h_total_tax_amount,
                   get_net_amount (aia.org_id, aia.invoice_id)
                       h_total_net_amount,
                   (SELECT SUM (NVL (line.amount, 0))
                      FROM ap_invoice_lines_all line
                     WHERE     line.org_id = aia.org_id
                           AND line.invoice_id = aia.invoice_id
                           AND line.line_type_lookup_code <> 'TAX')
                       h_total_net_amount_including_discount_charges,
                   aia.invoice_amount
                       h_invoice_total,
                   NVL (aila.description, aia.invoice_num)
                       invoice_line_description,
                   NVL (aila.unit_meas_lookup_code, 'EA')
                       unit_of_measure_code,
                   NVL (aila.quantity_invoiced, 1)
                       quantity_invoiced,
                   NVL (aila.unit_price, aila.amount)
                       unit_price,
                   aila.amount,
                   aila.amount
                       l_net_amount,
                   get_tax_exempt_code (aia.org_id,
                                        aia.invoice_id,
                                        aila.line_number)
                       l_tax_exemption_code,
                   get_tax_code (aia.org_id, aia.invoice_id)
                       tax_code/* ,(select sum(NVL(line.amount,0)) from ap_invoice_lines_all line
                                  where line.org_id =aia.org_id
                                  and line.invoice_id = aia.invoice_id
                                  and line.line_type_lookup_code <> 'TAX') l_net_amount*/
                               ,
                   get_vat_rate (aia.org_id,
                                 aia.invoice_id,
                                 aila.line_number)
                       vat_rate--   ,get_vat_amount(aia.org_id,aia.invoice_id,aila.line_number) vat_amount
                               --  ,get_vat_net_amount(aia.org_id,aia.invoice_id,aila.line_number) vat_net_amount
                               ,
                   aia.org_id,
                   aia.set_of_books_id,
                   get_comp_segment (aia.invoice_id,
                                     aila.line_number,
                                     aia.org_id)
                       company,
                   get_misc_amount (aia.org_id, aia.invoice_id)
                       h_charge_amount,
                   get_misc_tax_rate (aia.org_id, aia.invoice_id)
                       h_charge_tax_rate
              FROM ap_invoices_all aia, ap_invoice_lines_all aila, ap_payment_schedules_all apsa,
                   ap_suppliers aps, ap_supplier_sites_all apss, ap_terms apt
             WHERE     aia.invoice_id = aila.invoice_id
                   AND aia.invoice_id = apsa.invoice_id
                   AND apsa.hold_flag = 'Y'
                   AND aia.vendor_id = aps.vendor_id
                   AND aps.vendor_id = apss.vendor_id
                   AND aia.vendor_site_id = apss.vendor_site_id
                   AND aia.terms_id = apt.term_id
                   AND aia.org_id = pv_operating_unit
                   AND aia.invoice_id = NVL (pv_invoice_num, aia.invoice_id)
                   AND aia.invoice_date BETWEEN pv_from_date AND pv_to_date
                   AND ap_invoices_pkg.get_posting_status (aia.invoice_id) =
                       'Y'
                   AND EXISTS
                           (SELECT 1
                              FROM APPS.XXD_AP_CB_INV_STG cb
                             WHERE     cb.PROCESS_FLAG = 'Y'
                                   AND cb.invoice_id = aia.invoice_id)
                   AND aia.source IN
                           (SELECT UNIQUE ffv.attribute2
                              FROM fnd_flex_value_sets ffvs, fnd_flex_values ffv
                             WHERE     ffvs.flex_value_Set_name =
                                       'XXD_AP_CB_EXTRACT_MAPPING'
                                   AND ffvs.flex_value_set_id =
                                       ffv.flex_value_set_id
                                   AND ffv.enabled_flag = 'Y')
                   AND aila.line_type_lookup_code = 'ITEM'
                   AND aila.discarded_flag = 'N'
                   AND NVL (aps.num_1099, 'XX') NOT LIKE 'IT%'
                   AND NVL (apss.country, 'XX') <> 'IT';

        l_msg                        VARCHAR2 (4000);
        l_idx                        NUMBER;
        l_error_count                NUMBER;

        lv_filename                  VARCHAR2 (100);
        lv_error_code                VARCHAR2 (4000) := NULL;
        ln_error_num                 NUMBER;
        lv_error_msg                 VARCHAR2 (4000) := NULL;
        lv_status                    VARCHAR2 (10) := 'S';
        lv_period_status             VARCHAR2 (100);
        lv_ret_code                  VARCHAR2 (30) := NULL;
        lv_ret_message               VARCHAR2 (2000) := NULL;
        ln_ledger_id                 NUMBER;
        lv_period_start_date         DATE;
        lv_period_end_date           DATE;
        lv_begin_date                DATE;
        lv_end_date                  DATE;
        lv_invoice_end_date          DATE;
        lv_from_date                 DATE;
        lv_to_date                   DATE;
        lv_buyer_name                xle_entity_profiles.name%TYPE;
        lv_buyer_address_street      hr_locations.address_line_1%TYPE;
        lv_buyer_address_post_code   hr_locations.postal_code%TYPE;
        lv_buyer_address_city        hr_locations.town_or_city%TYPE;
        lv_buyer_address_province    hr_locations.region_1%TYPE;
        lv_buyer_country_code        hr_locations.country%TYPE;
        lv_buyer_vat_number          VARCHAR2 (50);
        l_inv_from_date              DATE;
        l_inv_to_date                DATE;
        ln_hdr_err_count             NUMBER := 0;
        ln_vendor_id                 NUMBER;
        lv_conc_error                VARCHAR2 (32767) := NULL;
        lv_gapless_seq               VARCHAR2 (100);
        l_vat_net_amount             NUMBER;
        l_vat_amount                 NUMBER;
        lv_inv_description           VARCHAR2 (260);
    BEGIN
        ln_ledger_id           := NULL;
        lv_period_start_date   := NULL;
        lv_period_end_date     := NULL;
        lv_begin_date          := NULL;
        lv_invoice_end_date    := NULL;

        get_le_details (
            pn_org_id                    => pv_operating_unit,
            xv_buyer_name                => lv_buyer_name,
            xv_buyer_address_street      => lv_buyer_address_street,
            xv_buyer_address_post_code   => lv_buyer_address_post_code,
            xv_buyer_address_city        => lv_buyer_address_city,
            xv_buyer_address_province    => lv_buyer_address_province,
            xv_buyer_country_code        => lv_buyer_country_code,
            xv_buyer_vat_number          => lv_buyer_vat_number);

        IF pv_reprocess = 'N'
        THEN
            FOR i IN cur_inv (pv_operating_unit, pv_invoice_num, pv_from_date
                              , pv_to_date)
            LOOP
                ln_hdr_err_count   := 0;
                -- validation starts

                l_vat_amount       :=
                    get_vat_amount (i.org_id, i.invoice_id, i.vat_rate);

                BEGIN
                    SELECT SUM (aila.amount)
                      INTO l_vat_net_amount
                      FROM ap_invoice_lines_all aila, zx_lines zx
                     WHERE     aila.invoice_id = i.invoice_id
                           AND aila.invoice_id = zx.trx_id
                           AND aila.line_number = zx.trx_line_number
                           AND zx.entity_code = 'AP_INVOICES'
                           AND zx.application_id = 200
                           AND zx.tax_line_number = 1
                           AND zx.internal_organization_id = i.org_id
                           AND aila.line_type_lookup_code <> 'TAX'
                           AND zx.tax_rate = i.vat_rate;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_vat_net_amount   := 0;
                END;

                IF i.payment_due_date IS NULL
                THEN
                    add_error_message (
                        i.invoice_id,
                        i.invoice_number,
                        i.invoice_date,
                        'PAYMENT_DUE_DATE_NULL',
                        'The Invoice Number does not have Payment Due Date ');
                    ln_hdr_err_count   := 1;
                    lv_conc_error      :=
                        lv_conc_error || ',' || 'PAYMENT_DUE_DATE_NULL';
                END IF;

                IF i.invoice_currency_code IS NULL
                THEN
                    add_error_message (
                        i.invoice_id,
                        i.invoice_number,
                        i.invoice_date,
                        'CURRENCY_CODE_NULL',
                        'The Invoice number does not have Currency Code ');
                    ln_hdr_err_count   := 1;
                    lv_conc_error      :=
                        lv_conc_error || ',' || 'CURRENCY_CODE_NULL';
                END IF;

                IF i.document_type IS NULL
                THEN
                    add_error_message (
                        i.invoice_id,
                        i.invoice_number,
                        i.invoice_date,
                        'DOCUMENT_TYPE_NULL',
                        'The Invoice number does not have Document Type ');
                    ln_hdr_err_count   := 1;
                    lv_conc_error      :=
                        lv_conc_error || ',' || 'DOCUMENT_TYPE_NULL';
                END IF;

                IF i.routing_code IS NULL
                THEN
                    add_error_message (
                        i.invoice_id,
                        i.invoice_number,
                        i.invoice_date,
                        'ROUTING_CODE_NULL',
                        'The Customer does not have Routing Code information ');
                    ln_hdr_err_count   := 1;
                    lv_conc_error      :=
                        lv_conc_error || ',' || 'ROUTING_CODE_NULL';
                END IF;

                IF lv_buyer_name IS NULL
                THEN
                    add_error_message (i.invoice_id,
                                       i.invoice_number,
                                       i.invoice_date,
                                       'INVALID_LEGAL_ENTITY',
                                       'Invalid Legal Entity Name ');
                    ln_hdr_err_count   := 1;
                    lv_conc_error      :=
                        lv_conc_error || ',' || 'INVALID_LEGAL_ENTITY';
                END IF;

                IF lv_buyer_address_street IS NULL
                THEN
                    add_error_message (
                        i.invoice_id,
                        i.invoice_number,
                        i.invoice_date,
                        'INVALID_LE_ADDRESS_STREET',
                        'Legal Entity does not have Address Street ');
                    ln_hdr_err_count   := 1;
                    lv_conc_error      :=
                        lv_conc_error || ',' || 'INVALID_LE_ADDRESS_STREET';
                END IF;

                IF lv_buyer_address_post_code IS NULL
                THEN
                    add_error_message (
                        i.invoice_id,
                        i.invoice_number,
                        i.invoice_date,
                        'INVALID_LE_POSTAL_CODE',
                        'Legal Entity does not have Postal Code ');
                    ln_hdr_err_count   := 1;
                    lv_conc_error      :=
                        lv_conc_error || ',' || 'INVALID_LE_POSTAL_CODE';
                END IF;

                IF lv_buyer_address_city IS NULL
                THEN
                    add_error_message (
                        i.invoice_id,
                        i.invoice_number,
                        i.invoice_date,
                        'INVALID_LE_CITY',
                        'Legal Entity does not have Address City ');
                    ln_hdr_err_count   := 1;
                    lv_conc_error      :=
                        lv_conc_error || ',' || 'INVALID_LE_CITY';
                END IF;

                IF lv_buyer_country_code IS NULL
                THEN
                    add_error_message (
                        i.invoice_id,
                        i.invoice_number,
                        i.invoice_date,
                        'INVALID_LE_COUNTRY_CODE',
                        'Legal Entity does not have Country Code');
                    ln_hdr_err_count   := 1;
                    lv_conc_error      :=
                        lv_conc_error || ',' || 'INVALID_LE_COUNTRY_CODE';
                END IF;

                IF i.vendor_name IS NULL
                THEN
                    add_error_message (
                        i.invoice_id,
                        i.invoice_number,
                        i.invoice_date,
                        'INVALID_VENDOR_NAME',
                        'The Invoice does not have Vendor Name information');
                    ln_hdr_err_count   := 1;
                    lv_conc_error      :=
                        lv_conc_error || ',' || 'INVALID_VENDOR_NAME';
                END IF;

                IF i.vendor_street IS NULL
                THEN
                    add_error_message (
                        i.invoice_id,
                        i.invoice_number,
                        i.invoice_date,
                        'INVALID_ADDRESS_STREET',
                        'The Vendor does not have address street information');
                    ln_hdr_err_count   := 1;
                    lv_conc_error      :=
                        lv_conc_error || ',' || 'INVALID_ADDRESS_STREET';
                END IF;

                IF i.vendor_post_code IS NULL
                THEN
                    add_error_message (
                        i.invoice_id,
                        i.invoice_number,
                        i.invoice_date,
                        'INVALID_ADDRESS_POST_CODE',
                        'The Vendor does not have postal code information');
                    ln_hdr_err_count   := 1;
                    lv_conc_error      :=
                        lv_conc_error || ',' || 'INVALID_ADDRESS_POST_CODE';
                END IF;

                IF i.vendor_address_city IS NULL
                THEN
                    add_error_message (
                        i.invoice_id,
                        i.invoice_number,
                        i.invoice_date,
                        'INVALID_ADDRESS_CITY',
                        'The Vendor does not have city information');
                    ln_hdr_err_count   := 1;
                    lv_conc_error      :=
                        lv_conc_error || ',' || 'INVALID_ADDRESS_CITY';
                END IF;

                IF i.vendor_address_country IS NULL
                THEN
                    add_error_message (
                        i.invoice_id,
                        i.invoice_number,
                        i.invoice_date,
                        'INVALID_ADDRESS_COUNTRY_CODE',
                        'The Vendor does not have country code');
                    ln_hdr_err_count   := 1;
                    lv_conc_error      :=
                           lv_conc_error
                        || ','
                        || 'INVALID_ADDRESS_COUNTRY_CODE';
                END IF;

                IF i.h_total_tax_amount IS NULL
                THEN
                    add_error_message (
                        i.invoice_id,
                        i.invoice_number,
                        i.invoice_date,
                        'INVALID_TOTAL_TAX_AMOUNT',
                        'Invalid Total tax amount of the invoice');
                    ln_hdr_err_count   := 1;
                    lv_conc_error      :=
                        lv_conc_error || ',' || 'INVALID_TOTAL_TAX_AMOUNT';
                END IF;

                IF i.h_total_net_amount IS NULL
                THEN
                    add_error_message (
                        i.invoice_id,
                        i.invoice_number,
                        i.invoice_date,
                        'INVALID_TOTAL_NET_AMOUNT',
                        'Invalid Total NET amount of the invoice');
                    ln_hdr_err_count   := 1;
                    lv_conc_error      :=
                        lv_conc_error || ',' || 'INVALID_TOTAL_NET_AMOUNT';
                END IF;

                IF i.h_total_net_amount_including_discount_charges IS NULL
                THEN
                    add_error_message (
                        i.invoice_id,
                        i.invoice_number,
                        i.invoice_date,
                        'INVALID_NET_AMT_INCL_DISCOUNTS',
                        'Invalid Total Invoice amount including discounts');
                    ln_hdr_err_count   := 1;
                    lv_conc_error      :=
                           lv_conc_error
                        || ','
                        || 'INVALID_NET_AMT_INCL_DISCOUNTS';
                END IF;

                IF i.h_invoice_total IS NULL
                THEN
                    add_error_message (i.invoice_id,
                                       i.invoice_number,
                                       i.invoice_date,
                                       'INVALID_INVOICE_TOTAL',
                                       'Invalid Total Invoice amount');
                    ln_hdr_err_count   := 1;
                    lv_conc_error      :=
                        lv_conc_error || ',' || 'INVALID_INVOICE_TOTAL';
                END IF;

                IF i.vat_rate IS NULL
                THEN
                    add_error_message (i.invoice_id,
                                       i.invoice_number,
                                       i.invoice_date,
                                       'INVALID_VAT_RATE',
                                       'The invoice does not have VAT rate');
                    ln_hdr_err_count   := 1;
                    lv_conc_error      :=
                        lv_conc_error || ',' || 'INVALID_VAT_RATE';
                END IF;

                IF l_vat_amount IS NULL
                THEN
                    add_error_message (
                        i.invoice_id,
                        i.invoice_number,
                        i.invoice_date,
                        'INVALID_VAT_AMOUNT',
                        'The invoice does not have VAT amount');
                    ln_hdr_err_count   := 1;
                    lv_conc_error      :=
                        lv_conc_error || ',' || 'INVALID_VAT_AMOUNT';
                END IF;

                IF l_vat_net_amount IS NULL
                THEN
                    add_error_message (
                        i.invoice_id,
                        i.invoice_number,
                        i.invoice_date,
                        'INVALID_VAT_NET_AMOUNT',
                        'The invoice does not have VAT Net amount');
                    ln_hdr_err_count   := 1;
                    lv_conc_error      :=
                        lv_conc_error || ',' || 'INVALID_VAT_NET_AMOUNT';
                END IF;

                IF i.l_net_amount IS NULL
                THEN
                    add_error_message (
                        i.invoice_id,
                        i.invoice_number,
                        i.invoice_date,
                        'INVALID_NET_AMOUNT',
                        'The invoice does not have Net amount');
                    ln_hdr_err_count   := 1;
                    lv_conc_error      :=
                        lv_conc_error || ',' || 'INVALID_NET_AMOUNT';
                END IF;

                IF i.unit_of_measure_code IS NULL
                THEN
                    add_error_message (i.invoice_id,
                                       i.invoice_number,
                                       i.invoice_date,
                                       'INVALID_UOM',
                                       'The invoice does not have UOM Code');
                    ln_hdr_err_count   := 1;
                    lv_conc_error      :=
                        lv_conc_error || ',' || 'INVALID_UOM';
                END IF;

                IF i.quantity_invoiced IS NULL
                THEN
                    add_error_message (
                        i.invoice_id,
                        i.invoice_number,
                        i.invoice_date,
                        'INVALID_INV_QTY',
                        'The invoice does not have quantity information');
                    ln_hdr_err_count   := 1;
                    lv_conc_error      :=
                        lv_conc_error || ',' || 'INVALID_INV_QTY';
                END IF;

                IF i.unit_price IS NULL
                THEN
                    add_error_message (
                        i.invoice_id,
                        i.invoice_number,
                        i.invoice_date,
                        'INVALID_UNIT_PRICE',
                        'The invoice does not have Unit Price information');
                    ln_hdr_err_count   := 1;
                    lv_conc_error      :=
                        lv_conc_error || ',' || 'INVALID_UNIT_PRICE';
                END IF;

                IF i.invoice_line_description IS NULL
                THEN
                    add_error_message (
                        i.invoice_id,
                        i.invoice_number,
                        i.invoice_date,
                        'INVALID_LINE_DESCRIPTION',
                        'Invoice Line Item does not have Description');
                    ln_hdr_err_count   := 1;
                    lv_conc_error      :=
                        lv_conc_error || ',' || 'INVALID_LINE_DESCRIPTION';
                END IF;

                IF (i.invoice_type_lookup_Code = 'CREDIT' AND i.invoice_doc_reference IS NULL)
                THEN
                    add_error_message (
                        i.invoice_id,
                        i.invoice_number,
                        i.invoice_date,
                        'ORIGINAL_INV_NUM_NULL',
                        'Original Invoice Number is null for Credit Memo invoice');
                    ln_hdr_err_count   := 1;
                    lv_conc_error      :=
                        lv_conc_error || ',' || 'ORIGINAL_INV_NUM_NULL';
                ELSIF (i.invoice_type_lookup_Code = 'CREDIT' AND i.invoice_doc_reference IS NOT NULL)
                THEN
                    -- original invoice vendor and CM vendor validation
                    BEGIN
                        SELECT vendor_id
                          INTO ln_vendor_id
                          FROM ap_invoices_all
                         WHERE     invoice_num = i.invoice_doc_reference
                               AND org_id = i.org_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_vendor_id   := NULL;
                    END;

                    IF NVL (ln_vendor_id, 0) <> i.vendor_id
                    THEN
                        add_error_message (i.invoice_id, i.invoice_number, i.invoice_date
                                           , 'VENDORS_MISMATCH', NULL);
                        ln_hdr_err_count   := 1;
                        lv_conc_error      :=
                            lv_conc_error || ',' || 'VENDORS_MISMATCH';
                    END IF;

                    BEGIN
                        SELECT attribute15
                          INTO lv_gapless_seq
                          FROM ap_invoices_all
                         WHERE     invoice_num = i.invoice_doc_reference
                               AND vendor_id = i.vendor_id
                               AND org_id = i.org_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_gapless_seq   := NULL;
                    END;

                    BEGIN
                        SELECT description
                          INTO lv_inv_description
                          FROM ap_invoices_all
                         WHERE     invoice_num = i.invoice_doc_reference
                               AND org_id = i.org_id;
                    --  fnd_file.put_line(fnd_file.log, 'invoice description' || lv_inv_description);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_inv_description   := NULL;
                    --  fnd_file.put_line(fnd_file.log, 'invoice description' || i.invoice_doc_reference);
                    END;

                    IF lv_gapless_seq IS NULL
                    THEN
                        add_error_message (i.invoice_id, i.invoice_number, i.invoice_date
                                           , 'GAPLESS_SEQ_NULL', NULL);
                        ln_hdr_err_count   := 1;
                        lv_conc_error      :=
                            lv_conc_error || ',' || 'GAPLESS_SEQ_NULL';
                    END IF;
                --
                END IF;


                BEGIN
                    INSERT INTO XXDO.XXD_AP_CB_INV_STG (INVOICE_ID, INVOICE_NUMBER, INVOICE_DATE, PAYMENT_DUE_DATE, PAYMENT_TERM, INVOICE_CURRENCY_CODE, DOCUMENT_TYPE, ORG_ID, SET_OF_BOOKS_ID, COMPANY, ROUTING_CODE, INVOICE_DOC_REFERENCE, INV_DOC_REF_DESC, VENDOR_NAME, VENDOR_VAT_NUMBER, VENDOR_STREET, VENDOR_POST_CODE, VENDOR_ADDRESS_CITY, VENDOR_ADDRESS_COUNTRY, BUYER_NAME, BUYER_VAT_NUMBER, BUYER_ADDRESS_STREET, BUYER_ADDRESS_POSTAL_CODE, BUYER_ADDRESS_CITY, BUYER_ADDRESS_PROVINCE, BUYER_ADDRESS_COUNTRY_CODE, H_TOTAL_TAX_AMOUNT, H_TOTAL_NET_AMOUNT, H_TOTAL_NET_AMOUNT_INCLUDING_DISCOUNT_CHARGES, H_INVOICE_TOTAL, VAT_NET_AMOUNT, VAT_RATE, VAT_AMOUNT, TAX_CODE, INVOICE_LINE_DESCRIPTION, UNIT_OF_MEASURE_CODE, QUANTITY_INVOICED, UNIT_PRICE, L_TAX_RATE, L_TAX_EXEMPTION_CODE, L_NET_AMOUNT, H_CHARGE_AMOUNT, H_CHARGE_DESCRIPTION, H_CHARGE_TAX_RATE, EXCHANGE_RATE, EXCHANGE_DATE, ORIGINAL_CURRENCY_CODE, CREATED_BY, CREATION_DATE, LAST_UPDATED_BY, LAST_UPDATE_DATE, LAST_UPDATE_LOGIN, CONC_REQUEST_ID, PROCESS_FLAG, REPROCESS_FLAG, EXTRACT_FLAG, EXTRACT_DATE
                                                        , ERROR_CODE)
                         VALUES (i.INVOICE_ID, remove_junk (i.INVOICE_NUMBER), TO_CHAR (i.INVOICE_DATE, 'DD-MON-YYYY'), TO_CHAR (i.PAYMENT_DUE_DATE, 'DD-MON-YYYY'), remove_junk (i.PAYMENT_TERM), 'EUR', i.DOCUMENT_TYPE, i.ORG_ID, i.SET_OF_BOOKS_ID, i.COMPANY, i.ROUTING_CODE, remove_junk (lv_gapless_seq) --i.INVOICE_DOC_REFERENCE)
                                                                                                                                                                                                                                                                                                               , remove_junk (lv_inv_description), remove_junk (i.VENDOR_NAME), remove_junk (NVL (i.VENDOR_VAT_NUMBER, i.VAT_REGISTRATION_NUM)), remove_junk (i.VENDOR_STREET), i.VENDOR_POST_CODE, remove_junk (i.VENDOR_ADDRESS_CITY), i.VENDOR_ADDRESS_COUNTRY, remove_junk (lv_buyer_name), remove_junk (lv_buyer_vat_number), remove_junk (lv_buyer_address_street), lv_buyer_address_post_code, remove_junk (lv_buyer_address_city), lv_buyer_address_province, remove_junk (lv_buyer_country_code), DECODE (i.invoice_currency_code, 'EUR', i.H_TOTAL_TAX_AMOUNT, ROUND ((i.H_TOTAL_TAX_AMOUNT * i.exchange_rate), 2)), DECODE (i.invoice_currency_code, 'EUR', i.H_TOTAL_NET_AMOUNT, ROUND ((i.H_TOTAL_NET_AMOUNT * i.exchange_rate), 2)), DECODE (i.invoice_currency_code, 'EUR', i.H_TOTAL_NET_AMOUNT_INCLUDING_DISCOUNT_CHARGES, ROUND ((i.H_TOTAL_NET_AMOUNT_INCLUDING_DISCOUNT_CHARGES * i.exchange_rate), 2)), DECODE (i.invoice_currency_code, 'EUR', (i.h_total_net_amount_including_discount_charges + i.h_total_tax_amount), --i.H_INVOICE_TOTAL
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               ROUND (((i.h_total_net_amount_including_discount_charges + i.h_total_tax_amount) * i.exchange_rate), 2)), DECODE (i.invoice_currency_code, 'EUR', l_vat_net_amount, -- VAT_NET_AMOUNT
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   ROUND ((l_vat_net_amount * i.exchange_rate), 2)), i.vat_rate, DECODE (i.invoice_currency_code, 'EUR', l_vat_amount, --VAT_AMOUNT
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       ROUND ((l_vat_amount * i.exchange_rate), 2)), remove_junk (DECODE (i.vat_rate, 0, i.tax_code, NULL)) --TAX_CODE
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           , remove_junk (i.INVOICE_LINE_DESCRIPTION), i.UNIT_OF_MEASURE_CODE, i.QUANTITY_INVOICED, DECODE (i.invoice_currency_code, 'EUR', i.UNIT_PRICE, ROUND ((i.UNIT_PRICE * i.exchange_rate), 2)), i.vat_rate --L_TAX_RATE
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  , DECODE (i.vat_rate, 0, i.l_tax_exemption_code, NULL) --L_TAX_EXEMPTION_CODE
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        , DECODE (i.invoice_currency_code, 'EUR', i.L_NET_AMOUNT, ROUND ((i.L_NET_AMOUNT * i.exchange_rate), 2)), DECODE (i.invoice_currency_code, 'EUR', DECODE (i.h_charge_amount,  0, NULL,  NULL, NULL,  i.h_charge_amount), ROUND ((DECODE (i.h_charge_amount,  0, NULL,  NULL, NULL,  i.h_charge_amount) * i.exchange_rate), 2)), DECODE (i.h_charge_amount,  0, NULL,  NULL, NULL,  'Miscellaneous Charges'), DECODE (i.h_charge_amount,  0, NULL,  NULL, NULL,  i.h_charge_tax_rate), DECODE (i.invoice_currency_code, 'EUR', NULL, i.exchange_rate), DECODE (i.invoice_currency_code, 'EUR', NULL, i.exchange_date), i.invoice_currency_code, gn_user_id, SYSDATE, gn_user_id, SYSDATE, gn_login_id, gn_request_id, 'N', 'N', NULL, NULL
                                 , NULL);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Failed to insert the data into custom table:'
                            || SQLERRM);
                END;

                BEGIN
                    IF ln_hdr_err_count = 1
                    THEN
                        UPDATE xxdo.xxd_ap_cb_inv_stg
                           SET process_flag = 'E', extract_flag = 'N', ERROR_CODE = SUBSTR (LTRIM (lv_conc_error, ','), 1, 4000),
                               last_update_date = SYSDATE, last_updated_by = gn_user_id
                         WHERE     conc_request_id = gn_request_id
                               AND invoice_id = i.invoice_Id;
                    END IF;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (fnd_file.LOG,
                                           'Failed to update:' || SQLERRM);
                END;
            END LOOP;

            COMMIT;

            populate_errors_table;
        --  COMMIT;

        END IF;

        IF pv_reprocess = 'Y'
        THEN
            FOR i IN cur_reprocess (pv_operating_unit, pv_invoice_num, pv_from_date
                                    , pv_to_date)
            LOOP
                l_vat_amount   :=
                    get_vat_amount (i.org_id, i.invoice_id, i.vat_rate);

                BEGIN
                    SELECT SUM (aila.amount)
                      INTO l_vat_net_amount
                      FROM ap_invoice_lines_all aila, zx_lines zx
                     WHERE     aila.invoice_id = i.invoice_id
                           AND aila.invoice_id = zx.trx_id
                           AND aila.line_number = zx.trx_line_number
                           AND zx.entity_code = 'AP_INVOICES'
                           AND zx.application_id = 200
                           AND zx.tax_line_number = 1
                           AND zx.internal_organization_id = i.org_id
                           AND aila.line_type_lookup_code <> 'TAX'
                           AND zx.tax_rate = i.vat_rate;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_vat_net_amount   := 0;
                END;


                BEGIN
                    INSERT INTO XXDO.XXD_AP_CB_INV_STG (INVOICE_ID, INVOICE_NUMBER, INVOICE_DATE, PAYMENT_DUE_DATE, PAYMENT_TERM, INVOICE_CURRENCY_CODE, DOCUMENT_TYPE, ORG_ID, SET_OF_BOOKS_ID, COMPANY, ROUTING_CODE, INVOICE_DOC_REFERENCE, INV_DOC_REF_DESC, VENDOR_NAME, VENDOR_VAT_NUMBER, VENDOR_STREET, VENDOR_POST_CODE, VENDOR_ADDRESS_CITY, VENDOR_ADDRESS_COUNTRY, BUYER_NAME, BUYER_VAT_NUMBER, BUYER_ADDRESS_STREET, BUYER_ADDRESS_POSTAL_CODE, BUYER_ADDRESS_CITY, BUYER_ADDRESS_PROVINCE, BUYER_ADDRESS_COUNTRY_CODE, H_TOTAL_TAX_AMOUNT, H_TOTAL_NET_AMOUNT, H_TOTAL_NET_AMOUNT_INCLUDING_DISCOUNT_CHARGES, H_INVOICE_TOTAL, VAT_NET_AMOUNT, VAT_RATE, VAT_AMOUNT, TAX_CODE, INVOICE_LINE_DESCRIPTION, UNIT_OF_MEASURE_CODE, QUANTITY_INVOICED, UNIT_PRICE, L_TAX_RATE, L_TAX_EXEMPTION_CODE, L_NET_AMOUNT, H_CHARGE_AMOUNT, H_CHARGE_DESCRIPTION, H_CHARGE_TAX_RATE, EXCHANGE_RATE, EXCHANGE_DATE, ORIGINAL_CURRENCY_CODE, CREATED_BY, CREATION_DATE, LAST_UPDATED_BY, LAST_UPDATE_DATE, LAST_UPDATE_LOGIN, CONC_REQUEST_ID, PROCESS_FLAG, REPROCESS_FLAG, EXTRACT_FLAG, EXTRACT_DATE
                                                        , ERROR_CODE)
                         VALUES (i.INVOICE_ID, remove_junk (i.INVOICE_NUMBER), TO_CHAR (i.INVOICE_DATE, 'DD-MON-YYYY'), TO_CHAR (i.PAYMENT_DUE_DATE, 'DD-MON-YYYY'), remove_junk (i.PAYMENT_TERM), 'EUR', i.DOCUMENT_TYPE, i.ORG_ID, i.SET_OF_BOOKS_ID, i.COMPANY, i.ROUTING_CODE, remove_junk (lv_gapless_seq), remove_junk (lv_inv_description), remove_junk (i.VENDOR_NAME), remove_junk (NVL (i.VENDOR_VAT_NUMBER, i.VAT_REGISTRATION_NUM)), remove_junk (i.VENDOR_STREET), i.VENDOR_POST_CODE, remove_junk (i.VENDOR_ADDRESS_CITY), i.VENDOR_ADDRESS_COUNTRY, remove_junk (lv_buyer_name), remove_junk (lv_buyer_vat_number), remove_junk (lv_buyer_address_street), lv_buyer_address_post_code, remove_junk (lv_buyer_address_city), lv_buyer_address_province, remove_junk (lv_buyer_country_code), DECODE (i.invoice_currency_code, 'EUR', i.H_TOTAL_TAX_AMOUNT, ROUND ((i.H_TOTAL_TAX_AMOUNT * ROUND (i.exchange_rate, 6)), 2)), DECODE (i.invoice_currency_code, 'EUR', i.H_TOTAL_NET_AMOUNT, ROUND ((i.H_TOTAL_NET_AMOUNT * ROUND (i.exchange_rate, 6)), 2)), DECODE (i.invoice_currency_code, 'EUR', i.H_TOTAL_NET_AMOUNT_INCLUDING_DISCOUNT_CHARGES, ROUND ((i.H_TOTAL_NET_AMOUNT_INCLUDING_DISCOUNT_CHARGES * ROUND (i.exchange_rate, 6)), 2)), DECODE (i.invoice_currency_code, 'EUR', (i.h_total_net_amount_including_discount_charges + i.h_total_tax_amount), --i.H_INVOICE_TOTAL
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                ROUND (((i.h_total_net_amount_including_discount_charges + i.h_total_tax_amount) * ROUND (i.exchange_rate, 6)), 2)), DECODE (i.invoice_currency_code, 'EUR', l_vat_net_amount, -- VAT_NET_AMOUNT
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               ROUND ((l_vat_net_amount * i.exchange_rate), 2)), i.vat_rate, DECODE (i.invoice_currency_code, 'EUR', l_vat_amount, --VAT_AMOUNT
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   ROUND ((l_vat_amount * i.exchange_rate), 2)), DECODE (i.vat_rate, 0, i.tax_code, NULL) -- tax_code
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         , remove_junk (i.INVOICE_LINE_DESCRIPTION), i.UNIT_OF_MEASURE_CODE, i.QUANTITY_INVOICED, DECODE (i.invoice_currency_code, 'EUR', i.UNIT_PRICE, ROUND ((i.UNIT_PRICE * i.exchange_rate), 2)), i.vat_rate --L_TAX_RATE
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                , DECODE (i.vat_rate, 0, i.l_tax_exemption_code, NULL) --L_TAX_EXEMPTION_CODE
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      , DECODE (i.invoice_currency_code, 'EUR', i.L_NET_AMOUNT, ROUND ((i.L_NET_AMOUNT * i.exchange_rate), 2)), DECODE (i.invoice_currency_code, 'EUR', DECODE (i.h_charge_amount,  0, NULL,  NULL, NULL,  i.h_charge_amount), ROUND ((DECODE (i.h_charge_amount,  0, NULL,  NULL, NULL,  i.h_charge_amount) * i.exchange_rate), 2)), DECODE (i.h_charge_amount,  0, NULL,  NULL, NULL,  'Miscellaneous Charges'), DECODE (i.h_charge_amount,  0, NULL,  NULL, NULL,  i.h_charge_tax_rate), DECODE (i.invoice_currency_code, 'EUR', NULL, i.exchange_rate), DECODE (i.invoice_currency_code, 'EUR', NULL, i.exchange_date), i.invoice_currency_code, gn_user_id, SYSDATE, gn_user_id, SYSDATE, gn_login_id, gn_request_id, 'N', 'Y', NULL, NULL
                                 , NULL);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Failed to insert the data into custom table:'
                            || SQLERRM);
                END;
            END LOOP;

            COMMIT;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'failed at insert_ap_eligible_recs exception');
            fnd_file.put_line (
                fnd_file.LOG,
                'Failed to insert the data into custom table:' || SQLERRM);
    END insert_ap_eligible_recs;

    PROCEDURE write_op_file (gn_request_id IN NUMBER, p_period_num IN VARCHAR2, x_ret_code OUT VARCHAR2
                             , x_ret_message OUT VARCHAR2)
    IS
        CURSOR get_hdr_cur IS
              SELECT invoice_id, invoice_number, company,
                     conc_request_id
                FROM xxdo.xxd_ap_cb_inv_stg
               WHERE     1 = 1
                     AND conc_request_id = gn_request_id
                     AND process_flag = 'N'
            GROUP BY invoice_id, invoice_number, company,
                     conc_request_id;

        CURSOR Cur_rec_select (p_invoice_id         NUMBER,
                               pv_Company           VARCHAR2,
                               pv_conc_request_id   NUMBER)
        IS
            SELECT DECODE (get_lookup_value ('INVOICE_ID', pv_Company), 'Y', STG.INVOICE_ID, '') || '||' || DECODE (get_lookup_value ('INVOICE_NUMBER', pv_Company), 'Y', STG.INVOICE_NUMBER, '') || '||' || DECODE (get_lookup_value ('INVOICE_DATE', pv_Company), 'Y', TO_CHAR (STG.INVOICE_DATE, 'DD-MON-YYYY'), '') || '||' || DECODE (get_lookup_value ('PAYMENT_DUE_DATE', pv_Company), 'Y', TO_CHAR (STG.PAYMENT_DUE_DATE, 'DD-MON-YYYY'), '') || '||' || DECODE (get_lookup_value ('PAYMENT_TERM', pv_Company), 'Y', STG.PAYMENT_TERM, '') || '||' || DECODE (get_lookup_value ('INVOICE_CURRENCY_CODE', pv_Company), 'Y', STG.INVOICE_CURRENCY_CODE, '') || '||' || DECODE (get_lookup_value ('DOCUMENT_TYPE', pv_Company), 'Y', STG.DOCUMENT_TYPE, '') || '||' || DECODE (get_lookup_value ('ROUTING_CODE', pv_Company), 'Y', STG.ROUTING_CODE, '') || '||' || DECODE (get_lookup_value ('INVOICE_DOC_REFERENCE', pv_Company), 'Y', STG.INVOICE_DOC_REFERENCE, '') || '||' || DECODE (get_lookup_value ('INV_DOC_REF_DESC', pv_Company), 'Y', STG.INV_DOC_REF_DESC, '') || '||' || DECODE (get_lookup_value ('VENDOR_NAME', pv_Company), 'Y', STG.VENDOR_NAME, '') || '||' || DECODE (get_lookup_value ('VENDOR_VAT_NUMBER', pv_Company), 'Y', STG.VENDOR_VAT_NUMBER, '') || '||' || DECODE (get_lookup_value ('VENDOR_STREET', pv_Company), 'Y', STG.VENDOR_STREET, '') || '||' || DECODE (get_lookup_value ('VENDOR_POST_CODE', pv_Company), 'Y', STG.VENDOR_POST_CODE, '') || '||' || DECODE (get_lookup_value ('VENDOR_ADDRESS_CITY', pv_Company), 'Y', STG.VENDOR_ADDRESS_CITY, '') || '||' || DECODE (get_lookup_value ('VENDOR_ADDRESS_COUNTRY', pv_Company), 'Y', STG.VENDOR_ADDRESS_COUNTRY, '') || '||' || DECODE (get_lookup_value ('BUYER_NAME', pv_Company), 'Y', STG.BUYER_NAME, '') || '||' || DECODE (get_lookup_value ('BUYER_VAT_NUMBER', pv_Company), 'Y', STG.BUYER_VAT_NUMBER, '') || '||' || DECODE (get_lookup_value ('BUYER_ADDRESS_STREET', pv_Company), 'Y', STG.BUYER_ADDRESS_STREET, '') || '||' || DECODE (get_lookup_value ('BUYER_ADDRESS_POSTAL_CODE', pv_Company), 'Y', STG.BUYER_ADDRESS_POSTAL_CODE, '') || '||' || DECODE (get_lookup_value ('BUYER_ADDRESS_CITY', pv_Company), 'Y', STG.BUYER_ADDRESS_CITY, '') || '||' || DECODE (get_lookup_value ('BUYER_ADDRESS_PROVINCE', pv_Company), 'Y', STG.BUYER_ADDRESS_PROVINCE, '') || '||' || DECODE (get_lookup_value ('BUYER_ADDRESS_COUNTRY_CODE', pv_Company), 'Y', STG.BUYER_ADDRESS_COUNTRY_CODE, '') || '||' || DECODE (get_lookup_value ('H_TOTAL_TAX_AMOUNT', pv_Company), 'Y', STG.H_TOTAL_TAX_AMOUNT, '') || '||' || DECODE (get_lookup_value ('H_TOTAL_NET_AMOUNT', pv_Company), 'Y', STG.H_TOTAL_NET_AMOUNT, '') || '||' || DECODE (get_lookup_value ('H_TOTAL_NET_AMOUNT_INCLUDING_DISCOUNT_CHARGES', pv_Company), 'Y', STG.H_TOTAL_NET_AMOUNT_INCLUDING_DISCOUNT_CHARGES, '') || '||' || DECODE (get_lookup_value ('H_INVOICE_TOTAL', pv_Company), 'Y', STG.H_INVOICE_TOTAL, '') || '||' || DECODE (get_lookup_value ('VAT_NET_AMOUNT', pv_Company), 'Y', STG.VAT_NET_AMOUNT, '') || '||' || DECODE (get_lookup_value ('VAT_RATE', pv_Company), 'Y', STG.VAT_RATE, '') || '||' || DECODE (get_lookup_value ('VAT_AMOUNT', pv_Company), 'Y', STG.VAT_AMOUNT, '') || '||' || DECODE (get_lookup_value ('TAX_CODE', pv_Company),  'Y', STG.TAX_CODE,  'C', STG.TAX_CODE,  '') || '||' || DECODE (get_lookup_value ('INVOICE_LINE_DESCRIPTION', pv_Company), 'Y', STG.INVOICE_LINE_DESCRIPTION, '') || '||' || DECODE (get_lookup_value ('UNIT_OF_MEASURE_CODE', pv_Company), 'Y', STG.UNIT_OF_MEASURE_CODE, '') || '||' || DECODE (get_lookup_value ('QUANTITY_INVOICED', pv_Company), 'Y', STG.QUANTITY_INVOICED, '') || '||' || DECODE (get_lookup_value ('UNIT_PRICE', pv_Company), 'Y', STG.UNIT_PRICE, '') || '||' || DECODE (get_lookup_value ('L_TAX_RATE', pv_Company), 'Y', STG.L_TAX_RATE, '') || '||' || DECODE (get_lookup_value ('L_TAX_EXEMPTION_CODE', pv_Company),  'Y', STG.L_TAX_EXEMPTION_CODE,  'C', STG.L_TAX_EXEMPTION_CODE,  '') || '||' || DECODE (get_lookup_value ('L_NET_AMOUNT', pv_Company), 'Y', STG.L_NET_AMOUNT, '') || '||' || DECODE (get_lookup_value ('H_CHARGE_AMOUNT', pv_Company), 'Y', STG.H_CHARGE_AMOUNT, '') || '||' || DECODE (get_lookup_value ('H_CHARGE_DESCRIPTION', pv_Company), 'Y', STG.H_CHARGE_DESCRIPTION, '') || '||' || DECODE (get_lookup_value ('H_CHARGE_TAX_RATE', pv_Company), 'Y', STG.H_CHARGE_TAX_RATE, '') || '||' || DECODE (get_lookup_value ('EXCHANGE_RATE', pv_Company), 'Y', STG.EXCHANGE_RATE, '') || '||' || DECODE (get_lookup_value ('EXCHANGE_DATE', pv_Company), 'Y', STG.EXCHANGE_DATE, '') || '||' || DECODE (get_lookup_value ('ORIGINAL_CURRENCY_CODE', pv_Company), 'Y', STG.ORIGINAL_CURRENCY_CODE, '') line
              FROM XXDO.XXD_AP_CB_INV_STG STG
             WHERE     1 = 1
                   AND conc_request_id = pv_conc_request_id
                   AND process_flag = 'N'
                   AND invoice_id = p_invoice_id;

        --lv_header_var           Cur_hdr_select%ROWTYPE;
        lv_file_path          VARCHAR2 (360);               -- := p_file_path;
        lv_file_name          VARCHAR2 (360);
        lv_file_dir           VARCHAR2 (1000);
        lv_output_file        UTL_FILE.file_type;
        lv_outbound_file      VARCHAR2 (360);               -- := p_file_name;
        lv_err_msg            VARCHAR2 (2000) := NULL;
        lv_line               VARCHAR2 (32767) := NULL;
        ln_ret_val            NUMBER;
        lv_inst_name          VARCHAR2 (100);
        lv_message            VARCHAR2 (32000);
        lv_msg                VARCHAR2 (4000) := NULL;
        lv_result             VARCHAR2 (100);
        lv_result_msg         VARCHAR2 (4000);
        lv_recipients         VARCHAR2 (500);
        v_def_mail_recips     do_mail_utils.tbl_recips;
        ex_no_recips          EXCEPTION;
        lv_email_body         VARCHAR2 (2000);
        lv_emp_name           VARCHAR2 (100);
        lv_user_name          VARCHAR2 (100);
        gn_success   CONSTANT NUMBER := 0;
        gn_warning   CONSTANT NUMBER := 1;
        gn_error     CONSTANT NUMBER := 2;
    BEGIN
        FOR i IN get_hdr_cur
        LOOP
            ln_ret_val      := 0;
            lv_file_name    := NULL;
            lv_line         := NULL;
            lv_message      := NULL;
            lv_msg          := NULL;
            lv_result       := NULL;
            lv_result_msg   := NULL;

            lv_file_name    :=
                   'APX'
                || i.invoice_id
                || p_period_num
                || TO_CHAR (SYSDATE, 'DDMMRRRRHH24MISS')
                || '.csv';

            lv_line         :=
                   'INVOICE_ID'
                || '||'
                || 'INVOICE_NUMBER'
                || '||'
                || 'INVOICE_DATE'
                || '||'
                || 'PAYMENT_DUE_DATE'
                || '||'
                || 'PAYMENT_TERM'
                || '||'
                || 'INVOICE_CURRENCY_CODE'
                || '||'
                || 'DOCUMENT_TYPE'
                || '||'
                || 'ROUTING_CODE'
                || '||'
                || 'INVOICE_DOC_REFERENCE'
                || '||'
                || 'INV_DOC_REF_DESC'
                || '||'
                || 'VENDOR_NAME'
                || '||'
                || 'VENDOR_VAT_NUMBER'
                || '||'
                || 'VENDOR_STREET'
                || '||'
                || 'VENDOR_POST_CODE'
                || '||'
                || 'VENDOR_ADDRESS_CITY'
                || '||'
                || 'VENDOR_ADDRESS_COUNTRY'
                || '||'
                || 'BUYER_NAME'
                || '||'
                || 'BUYER_VAT_NUMBER'
                || '||'
                || 'BUYER_ADDRESS_STREET'
                || '||'
                || 'BUYER_ADDRESS_POSTAL_CODE'
                || '||'
                || 'BUYER_ADDRESS_CITY'
                || '||'
                || 'BUYER_ADDRESS_PROVINCE'
                || '||'
                || 'BUYER_ADDRESS_COUNTRY_CODE'
                || '||'
                || 'H_TOTAL_TAX_AMOUNT'
                || '||'
                || 'H_TOTAL_NET_AMOUNT'
                || '||'
                || 'H_TOTAL_NET_AMOUNT_INCLUDING_DISCOUNT_CHARGES'
                || '||'
                || 'H_INVOICE_TOTAL'
                || '||'
                || 'VAT_NET_AMOUNT'
                || '||'
                || 'VAT_RATE'
                || '||'
                || 'VAT_AMOUNT'
                || '||'
                || 'TAX_CODE'
                || '||'
                || 'INVOICE_LINE_DESCRIPTION'
                || '||'
                || 'UNIT_OF_MEASURE_CODE'
                || '||'
                || 'QUANTITY_INVOICED'
                || '||'
                || 'UNIT_PRICE'
                || '||'
                || 'L_TAX_RATE'
                || '||'
                || 'L_TAX_EXEMPTION_CODE'
                || '||'
                || 'L_NET_AMOUNT'
                || '||'
                || 'H_CHARGE_AMOUNT'
                || '||'
                || 'H_CHARGE_DESCRIPTION'
                || '||'
                || 'H_CHARGE_TAX_RATE'
                || '||'
                || 'EXCHANGE_RATE'
                || '||'
                || 'EXCHANGE_DATE'
                || '||'
                || 'ORIGINAL_CURRENCY_CODE';

            apps.fnd_file.put_line (fnd_file.output, lv_line);

            lv_output_file   :=
                UTL_FILE.fopen ('XXD_AP_SDI_CB_OUT_DIR', --'XXD_GL_TRAIL_BALANCE_DIR',
                                                         lv_file_name, 'W' --opening the file in write mode
                                                                          ,
                                32767);

            IF UTL_FILE.is_open (lv_output_file)
            THEN
                apps.fnd_file.put_line (fnd_file.LOG, 'File is Open');
                UTL_FILE.put_line (lv_output_file, 'Deckers');
                UTL_FILE.put_line (lv_output_file,
                                   'E-Invoicing Pagero Inter-Company');
                UTL_FILE.put_line (lv_output_file, 'AP CB Export');
                UTL_FILE.put_line (lv_output_file, ' ');

                UTL_FILE.put_line (lv_output_file, lv_line);

                FOR rec
                    IN Cur_rec_select (i.invoice_id,
                                       i.company,
                                       i.conc_request_id)
                LOOP
                    lv_line   := rec.line;
                    apps.fnd_file.put_line (fnd_file.output, rec.line);
                    UTL_FILE.put_line (lv_output_file, lv_line);
                END LOOP;
            ELSE
                apps.fnd_file.put_line (fnd_file.LOG, 'File is not Open');
                lv_err_msg      :=
                    SUBSTR (
                           'Error in Opening the  data file for writing. Error is : '
                        || SQLERRM,
                        1,
                        2000);
                print_log (lv_err_msg);
                x_ret_code      := gn_error;
                x_ret_message   := lv_err_msg;
                RETURN;
            END IF;

            --
            BEGIN
                UPDATE xxdo.xxd_ap_cb_inv_stg
                   SET process_flag = 'Y', extract_flag = 'Y', extract_date = SYSDATE,
                       file_name = lv_file_name, last_updated_by = gn_user_id, last_update_date = SYSDATE
                 WHERE     conc_request_id = i.conc_request_id
                       AND process_flag = 'N'
                       AND invoice_id = i.invoice_Id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;

            --added as part of this CCR0010453
            UTL_FILE.fclose (lv_output_file);
        END LOOP;
    -- as part of this CCR0010453, commented below piece of code
    -- UTL_FILE.fclose (lv_output_file);

    EXCEPTION
        WHEN UTL_FILE.invalid_path
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      :=
                'INVALID_PATH: File location or filename was invalid.';
            print_log (lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20101, lv_err_msg);
        WHEN UTL_FILE.invalid_mode
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      :=
                'INVALID_MODE: The open_mode parameter in FOPEN was invalid.';
            print_log (lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20102, lv_err_msg);
        WHEN UTL_FILE.invalid_filehandle
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      :=
                'INVALID_FILEHANDLE: The file handle was invalid.';
            print_log (lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20103, lv_err_msg);
        WHEN UTL_FILE.invalid_operation
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      :=
                'INVALID_OPERATION: The file could not be opened or operated on as requested.';
            print_log (lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20104, lv_err_msg);
        WHEN UTL_FILE.read_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      :=
                'READ_ERROR: An operating system error occurred during the read operation.';
            print_log (lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20105, lv_err_msg);
        WHEN UTL_FILE.write_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      :=
                'WRITE_ERROR: An operating system error occurred during the write operation.';
            print_log (lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20106, lv_err_msg);
        WHEN UTL_FILE.internal_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      := 'INTERNAL_ERROR: An unspecified error in PL/SQL.';
            print_log (lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20107, lv_err_msg);
        WHEN UTL_FILE.invalid_filename
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      :=
                'INVALID_FILENAME: The filename parameter is invalid.';
            print_log (lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20108, lv_err_msg);
        WHEN ex_no_recips
        THEN
            lv_err_msg      :=
                SUBSTR (
                       'There were no recipients configured to receive the alert.'
                    || SQLERRM,
                    1,
                    2000);

            print_log (lv_err_msg);

            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20109, lv_err_msg);            --Be Safe
        WHEN OTHERS
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      :=
                SUBSTR (
                       'Error while creating or writing the data into the file.'
                    || SQLERRM,
                    1,
                    2000);

            print_log (lv_err_msg);

            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20110, lv_err_msg);
    END write_op_file;

    PROCEDURE main (errbuf OUT NOCOPY VARCHAR2, retcode OUT NOCOPY VARCHAR2, pn_operating_unit IN NUMBER, pv_reprocess IN VARCHAR2, pv_inv_enabled_tmp IN VARCHAR2, pv_invoice_number IN NUMBER
                    , pv_end_date IN VARCHAR2, pv_mode IN VARCHAR2)
    AS
        --Define Variables
        lv_ret_code           VARCHAR2 (30) := NULL;
        lv_ret_message        VARCHAR2 (2000) := NULL;
        l_inv_from_date       DATE;
        l_inv_to_date         DATE;
        lv_invoice_end_date   DATE;
        l_period_num          VARCHAR2 (10);
    BEGIN
        -- Printing all the parameters
        fnd_file.put_line (
            fnd_file.LOG,
            'Deckers AP Cross-Border Invoice Outbound Integration Program.....');
        fnd_file.put_line (fnd_file.LOG, 'Parameters Are.....');
        fnd_file.put_line (fnd_file.LOG, '-------------------');
        fnd_file.put_line (fnd_file.LOG,
                           'pn_operating_unit:' || pn_operating_unit);
        fnd_file.put_line (fnd_file.LOG, 'pv_reprocess   :' || pv_reprocess);
        fnd_file.put_line (fnd_file.LOG,
                           'pv_invoice_number    :' || pv_invoice_number);
        fnd_file.put_line (fnd_file.LOG, 'pv_end_date    :' || pv_end_date);
        fnd_file.put_line (fnd_file.LOG, 'pv_mode    :' || pv_mode);

        --
        lv_invoice_end_date   :=
            TO_DATE (pv_end_date, 'RRRR/MM/DD HH24:MI:SS');

        BEGIN
            SELECT start_date, end_date, TO_CHAR (TO_DATE (entered_period_name, 'mon'), 'mm') period_num
              INTO l_inv_from_date, l_inv_to_date, l_period_num
              FROM apps.gl_periods
             WHERE     period_set_name = 'DO_FY_CALENDAR'
                   AND (lv_invoice_end_date) BETWEEN start_date AND end_date;
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END;

        IF pv_mode = 'Hold'
        THEN
            apply_hold_prc (pn_operating_unit, pv_reprocess, pv_invoice_number
                            , l_inv_from_date, l_inv_to_date);
        ELSIF pv_mode = 'Extract'
        THEN
            --Insert data into Staging tables
            insert_ap_eligible_recs (pv_operating_unit => pn_operating_unit, pv_reprocess => pv_reprocess, pv_invoice_num => pv_invoice_number, pv_from_date => l_inv_from_date, pv_to_date => l_inv_to_date, x_ret_code => lv_ret_code
                                     , x_ret_message => lv_ret_message);

            write_op_file (gn_request_id => gn_request_id, p_period_num => l_period_num, x_ret_code => lv_ret_code
                           , x_ret_message => lv_ret_message);

            generate_report_prc (p_conc_request_id => gn_request_id);
        ELSIF pv_mode = 'Hold and Extract'
        THEN
            apply_hold_prc (pn_operating_unit, pv_reprocess, pv_invoice_number
                            , l_inv_from_date, l_inv_to_date);

            insert_ap_eligible_recs (pv_operating_unit => pn_operating_unit, pv_reprocess => pv_reprocess, pv_invoice_num => pv_invoice_number, pv_from_date => l_inv_from_date, pv_to_date => l_inv_to_date, x_ret_code => lv_ret_code
                                     , x_ret_message => lv_ret_message);

            write_op_file (gn_request_id => gn_request_id, p_period_num => l_period_num, x_ret_code => lv_ret_code
                           , x_ret_message => lv_ret_message);

            generate_report_prc (p_conc_request_id => gn_request_id);
        ELSIF pv_mode = 'Release'
        THEN
            release_holds_prc (pn_operating_unit, pv_reprocess, pv_invoice_number
                               , l_inv_from_date, l_inv_to_date);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_log ('Error occured in main procedure' || SQLERRM);
    END main;
END XXD_AP_CB_INV_OUTBOUND_PKG;
/
