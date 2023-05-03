--
-- XXD_AP_DEF_ACCT_UPDATE_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:31:52 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_AP_DEF_ACCT_UPDATE_PKG"
AS
    --  ###################################################################################################
    --  Author(s)       : Tejaswi Gangumalla (Suneratech Consultant)
    --  System          : Oracle Applications
    --  Schema          : APPS
    --  Purpose         : Created package for validating deffered account values enterd at po requistion and updating deffered account values in ap invoice
    --  Dependency      : None
    --  Change History
    --  --------------
    --  Date            Name                Ver     Change          Description
    --  ----------      --------------      -----   -------------   ---------------------
    --  09-Jul-2018    Tejaswi Gsngumalla   1.0     NA              Initial Version
    --  ####################################################################################################
    PROCEDURE update_deferred_values (pn_invoice_id   IN     NUMBER,
                                      pv_error_msg       OUT VARCHAR2)
    IS
        lv_manual_def_flag        VARCHAR2 (2) := 'N';
        lv_def_start_date_valid   VARCHAR2 (3);
        ln_hold_count             NUMBER := 0;
        lv_hold_msg               VARCHAR2 (2000)
            := 'Deferred Account Start Date Not In Open Period For Lines: ';
        ln_ext_hold_count         NUMBER := 0;

        CURSOR invoice_lines_details IS
            SELECT ail.deferred_acctg_flag, ail.def_acctg_start_date, ail.def_acctg_end_date,
                   aid.po_distribution_id, ail.org_id, ail.line_number inv_line_number,
                   pda.po_header_id, pda.po_line_id, rl.attribute11 req_deff_flag,
                   fnd_date.canonical_to_date (rl.attribute12) req_start_date, fnd_date.canonical_to_date (rl.attribute13) req_end_date, rl.attribute12,
                   mc.segment1 req_line_category, pha.authorization_status, ail.line_number invoice_line_number
              FROM ap_invoices_all aia, ap_invoice_lines_all ail, ap_invoice_distributions_all aid,
                   po_distributions_all pda, po_headers_all pha, po_req_distributions_all prd,
                   po_requisition_lines_all rl, mtl_categories_b mc
             WHERE     aia.invoice_id = ail.invoice_id
                   AND aid.invoice_id = ail.invoice_id
                   AND aid.invoice_line_number = ail.line_number
                   AND ail.line_type_lookup_code = 'ITEM'
                   AND aia.invoice_id = pn_invoice_id
                   AND pda.po_distribution_id = aid.po_distribution_id
                   AND pda.po_header_id = pha.po_header_id
                   AND pda.req_distribution_id = prd.distribution_id
                   AND prd.requisition_line_id = rl.requisition_line_id
                   AND mc.category_id = rl.category_id;
    BEGIN
        --Get attribute13 from ap_invoices_all to check if deferred acct is manuall  or automatic
        BEGIN
            SELECT attribute13
              INTO lv_manual_def_flag
              FROM ap_invoices_all
             WHERE invoice_id = pn_invoice_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_manual_def_flag   := '';
        END;

        BEGIN
            SELECT COUNT (*)
              INTO ln_ext_hold_count
              FROM ap_holds_all
             WHERE     hold_lookup_code = 'Deckers Deferred Accounti'
                   AND invoice_id = pn_invoice_id
                   AND release_lookup_code IS NULL;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_ext_hold_count   := 0;
        END;

        --If attribute13 is null or 'N' deferred acct has to done else its is manually done
        IF NVL (lv_manual_def_flag, 'N') = 'N'
        THEN
            FOR invoice_lines_rec IN invoice_lines_details
            LOOP
                lv_def_start_date_valid   := NULL;

                IF     NVL (invoice_lines_rec.req_deff_flag, 'N') = 'Y'
                   AND invoice_lines_rec.req_start_date IS NOT NULL
                   AND invoice_lines_rec.req_end_date IS NOT NULL
                   AND invoice_lines_rec.req_line_category = 'Non-Trade'
                   AND invoice_lines_rec.authorization_status = 'APPROVED'
                   --AND NVL (invoice_lines_rec.deferred_acctg_flag, 'N') = 'N'
                   AND (NVL (invoice_lines_rec.def_acctg_start_date, '31-DEC-9999') <> invoice_lines_rec.req_start_date OR NVL (invoice_lines_rec.def_acctg_end_date, '31-DEC-9999') <> invoice_lines_rec.req_end_date)
                THEN
                    --Check if deferred start date is valid
                    lv_def_start_date_valid   :=
                        validate_deferred_dates (
                            invoice_lines_rec.org_id,
                            invoice_lines_rec.attribute12);

                    --If deferred start date is not valid put the incoice on hold
                    IF lv_def_start_date_valid = 'N'
                    THEN
                        lv_hold_msg     :=
                               lv_hold_msg
                            || invoice_lines_rec.inv_line_number
                            || ',';
                        ln_hold_count   := ln_hold_count + 1;
                    END IF;

                    --Upddate ap invoice with deferred values
                    BEGIN
                        UPDATE ap_invoice_lines_all
                           SET deferred_acctg_flag = invoice_lines_rec.req_deff_flag, def_acctg_start_date = invoice_lines_rec.req_start_date, def_acctg_end_date = invoice_lines_rec.req_end_date
                         WHERE     invoice_id = pn_invoice_id
                               AND line_number =
                                   invoice_lines_rec.invoice_line_number;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            pv_error_msg   :=
                                   'Error While Updating invoice with deferred acct values '
                                || SQLERRM;
                    END;
                ELSIF     NVL (invoice_lines_rec.req_deff_flag, 'N') = 'Y'
                      AND invoice_lines_rec.req_start_date IS NOT NULL
                      AND invoice_lines_rec.req_end_date IS NOT NULL
                      AND invoice_lines_rec.req_line_category = 'Non-Trade'
                      AND invoice_lines_rec.authorization_status = 'APPROVED'
                      AND NVL (invoice_lines_rec.deferred_acctg_flag, 'N') =
                          'Y'
                      AND invoice_lines_rec.def_acctg_start_date IS NOT NULL
                      AND invoice_lines_rec.def_acctg_end_date IS NOT NULL
                      AND ln_ext_hold_count = 0
                THEN
                    lv_def_start_date_valid   :=
                        validate_deferred_dates (
                            invoice_lines_rec.org_id,
                            invoice_lines_rec.attribute12);

                    --If deferred start date is not valid put the incoice on hold
                    IF lv_def_start_date_valid = 'N'
                    THEN
                        lv_hold_msg     :=
                               lv_hold_msg
                            || invoice_lines_rec.inv_line_number
                            || ',';
                        ln_hold_count   := ln_hold_count + 1;
                    END IF;

                    IF    invoice_lines_rec.def_acctg_start_date <>
                          invoice_lines_rec.req_start_date
                       OR invoice_lines_rec.def_acctg_end_date <>
                          invoice_lines_rec.req_end_date
                    THEN
                        UPDATE ap_invoice_lines_all
                           SET deferred_acctg_flag = invoice_lines_rec.req_deff_flag, def_acctg_start_date = invoice_lines_rec.req_start_date, def_acctg_end_date = invoice_lines_rec.req_end_date
                         WHERE     invoice_id = pn_invoice_id
                               AND line_number =
                                   invoice_lines_rec.invoice_line_number;
                    END IF;
                END IF;
            END LOOP;
        ELSE
            FOR invoice_lines_rec IN invoice_lines_details
            LOOP
                IF     NVL (invoice_lines_rec.req_deff_flag, 'N') = 'Y'
                   AND invoice_lines_rec.req_start_date IS NOT NULL
                   AND invoice_lines_rec.req_end_date IS NOT NULL
                   AND invoice_lines_rec.req_line_category = 'Non-Trade'
                   AND invoice_lines_rec.authorization_status = 'APPROVED'
                   AND NVL (invoice_lines_rec.deferred_acctg_flag, 'N') = 'Y'
                   AND invoice_lines_rec.def_acctg_start_date =
                       invoice_lines_rec.req_start_date
                   AND invoice_lines_rec.def_acctg_end_date =
                       invoice_lines_rec.req_end_date
                THEN
                    lv_def_start_date_valid   :=
                        validate_deferred_dates (
                            invoice_lines_rec.org_id,
                            invoice_lines_rec.attribute12);

                    --If deferred start date is not valid put the incoice on hold
                    IF lv_def_start_date_valid = 'N'
                    THEN
                        lv_hold_msg     :=
                               lv_hold_msg
                            || invoice_lines_rec.inv_line_number
                            || ',';
                        ln_hold_count   := ln_hold_count + 1;
                    END IF;
                END IF;
            END LOOP;
        END IF;


        IF ln_hold_count > 0
        THEN
            lv_hold_msg   :=
                SUBSTR (lv_hold_msg, 0, (LENGTH (lv_hold_msg) - 1));
            ap_holds_pkg.insert_single_hold (
                x_invoice_id         => pn_invoice_id,
                x_hold_lookup_code   => 'Deckers Deferred Accounti',
                x_hold_type          => 'INVOICE HOLD REASON',
                x_hold_reason        => lv_hold_msg,
                x_held_by            => '',
                x_calling_sequence   => '');
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_error_msg   := pv_error_msg || ' ' || SQLERRM;
    END update_deferred_values;

    FUNCTION validate_deferred_dates (pn_org_id            IN NUMBER,
                                      pv_deff_start_date   IN VARCHAR2)
        RETURN VARCHAR2
    IS
        ln_ledger_id    NUMBER;
        ln_count        NUMBER;
        ln_valid_flag   VARCHAR2 (2);
        ld_start_date   DATE;
    BEGIN
        BEGIN
            SELECT DISTINCT ledger_id
              INTO ln_ledger_id
              FROM xle_le_ou_ledger_v
             WHERE operating_unit_id = pn_org_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_ledger_id   := NULL;
        END;

        BEGIN
            SELECT fnd_date.canonical_to_date (pv_deff_start_date)
              INTO ld_start_date
              FROM DUAL;
        EXCEPTION
            WHEN OTHERS
            THEN
                ld_start_date   := pv_deff_start_date;
        END;

        BEGIN
            SELECT COUNT (*)
              INTO ln_count
              FROM gl_period_statuses ps
             WHERE     ps.adjustment_period_flag = 'N'
                   AND (ld_start_date BETWEEN TRUNC (ps.start_date) AND TRUNC (ps.end_date))
                   AND ps.ledger_id = ln_ledger_id
                   AND ps.closing_status IN ('O', 'F')
                   AND ps.application_id = 200;                           --ap
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_count   := 0;
        END;

        IF ln_count > 0
        THEN
            ln_valid_flag   := 'Y';
        ELSE
            ln_valid_flag   := 'N';
        END IF;

        RETURN ln_valid_flag;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 'N';
    END validate_deferred_dates;
END xxd_ap_def_acct_update_pkg;
/
