--
-- XXD_AR_IC_INV_OUTBOUND_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:31:26 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_AR_IC_INV_OUTBOUND_PKG"
AS
    /***************************************************************************************
    * Program Name : XXDO_AR_IC_INV_OUTBOUND_PKG                                           *
    * Language     : PL/SQL                                                                *
    * Description  : Package to extract AR intercompany invoices                           *
    *                                                                                      *
    * History      :                                                                       *
    *                                                                                      *
    * WHO          :       WHAT      Desc                                    WHEN          *
    * -------------- ----------------------------------------------------------------------*
    * Kishan Reddy         1.0       Initial Version                         15-SEP-2022   *
    * Kishan Reddy         1.1       CCR0010417: Skip partial                24-JAN-2023   *
    *                                invoice line Extract                                  *
    * Kishan Reddy         1.2       CCR0010453 : File generation issue      08-FEB-2023   *
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
            INSERT INTO XXDO.xxd_ap_ic_inv_errors_gt
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


    FUNCTION get_vat_rate (p_invoice_id     IN NUMBER,
                           p_attribute_id   IN NUMBER,
                           p_line_number    IN NUMBER)
        RETURN NUMBER
    IS
        ln_vat_rate   NUMBER;
    BEGIN
        SELECT ic_tax_rate
          INTO ln_vat_rate
          FROM xxcp_ic_inv_lines
         WHERE     invoice_header_id = p_invoice_id
               AND attribute_id = p_attribute_id
               AND attribute10 = 'T';

        RETURN ln_vat_rate;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_log ('Error occured while fectching get_vat_rate  ');
            RETURN 0;
    END get_vat_rate;

    FUNCTION get_vat_amount (p_company IN VARCHAR2, p_invoice_id IN NUMBER, p_ic_tax_rate IN NUMBER
                             , p_tax_code IN VARCHAR2)
        RETURN NUMBER
    IS
        ln_vat_amount   NUMBER;
    BEGIN
        IF p_ic_tax_rate <> 0
        THEN
            SELECT ROUND (SUM (xil.quantity * xil.ic_tax_amount), 2)
              INTO ln_vat_amount
              FROM apps.xxcp_ic_inv_lines xil, apps.xxcp_ic_inv_header xih
             WHERE     1 = 1
                   AND xih.invoice_header_id = xil.invoice_header_id
                   AND xih.invoice_header_id = p_invoice_id
                   AND xih.attribute2 = p_company
                   AND xil.attribute10 IN ('S', 'O')
                   AND xil.ic_tax_rate = p_ic_tax_rate;
        ELSE
            BEGIN
                SELECT vat_amount
                  INTO ln_vat_amount
                  FROM (  SELECT ROUND (SUM (xil.quantity * xil.ic_tax_amount), 2) vat_amount, SUBSTR (description, 1, (INSTR (description, ':') - 1)) natura_code
                            FROM apps.xxcp_ic_inv_lines xil, apps.xxcp_ic_inv_header xih, fnd_lookup_Values flv
                           WHERE     1 = 1
                                 AND xih.invoice_header_id =
                                     xil.invoice_header_id
                                 AND xih.invoice_header_id = p_invoice_id
                                 AND xih.attribute2 = p_company
                                 AND xil.attribute10 IN ('S', 'O')
                                 AND xil.ic_tax_rate = p_ic_tax_rate
                                 AND xil.ic_tax_code = flv.lookup_code
                                 AND flv.lookup_type =
                                     'XXD_ARIC_VT_TAX_CODE_MAPPING'
                                 AND flv.enabled_flag = 'Y'
                                 AND SYSDATE BETWEEN NVL (
                                                         flv.start_date_Active,
                                                         SYSDATE)
                                                 AND NVL (flv.end_date_active,
                                                          SYSDATE + 1)
                                 AND flv.language = 'US'
                        GROUP BY description)
                 WHERE     1 = 1
                       AND natura_code =
                           (SELECT SUBSTR (fl.description, 1, (INSTR (fl.description, ':') - 1))
                              FROM fnd_lookup_values fl
                             WHERE     1 = 1
                                   AND fl.language = 'US'
                                   AND fl.enabled_flag = 'Y'
                                   AND SYSDATE BETWEEN NVL (
                                                           fl.start_date_Active,
                                                           SYSDATE)
                                                   AND NVL (
                                                           fl.end_date_active,
                                                           SYSDATE + 1)
                                   AND fl.lookup_type =
                                       'XXD_ARIC_VT_TAX_CODE_MAPPING'
                                   AND fl.lookup_code = p_tax_code);
            EXCEPTION
                WHEN OTHERS
                THEN
                    RETURN 0;
            END;
        END IF;

        RETURN ln_vat_amount;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_log ('Error occured while fectching get_vat_amount  ');
            RETURN 0;
    END get_vat_amount;

    FUNCTION get_ap_vat_amount (p_company IN VARCHAR2, p_invoice_id IN NUMBER, p_attribute_id IN NUMBER)
        RETURN NUMBER
    IS
        ln_vat_amount   NUMBER;
    BEGIN
        SELECT SUM (NVL (entered_dr, entered_cr))
          INTO ln_vat_amount
          FROM apps.xxcp_process_history ph, apps.xxcp_ic_inv_lines xils
         WHERE     ph.attribute_id = xils.attribute_id
               AND xils.invoice_header_id = p_invoice_id
               AND xils.attribute10 IN ('S', 'O')
               AND NOT EXISTS
                       (SELECT 1
                          FROM xxcp_account_rules xar
                         WHERE     NVL (xar.rule_category_1, 'X') = 'REVERSE'
                               AND xar.rule_id = xils.transaction_rule_id)
               AND ph.segment1 = p_company
               AND ph.status = 'GLI'
               AND ph.segment6 IN ('11901', '11902');

        RETURN ln_vat_amount;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_log ('Error occured while fectching get_vat_amount  ');
            RETURN 0;
    END get_ap_vat_amount;

    FUNCTION get_vat_net_amount (p_company IN VARCHAR2, p_invoice_id IN NUMBER, p_ic_tax_rate IN NUMBER
                                 , p_tax_code IN VARCHAR2)
        RETURN NUMBER
    IS
        ln_vat_amount   NUMBER;
    BEGIN
        IF p_ic_tax_rate <> 0
        THEN
            SELECT ROUND (SUM (xil.quantity * xil.ic_unit_price), 2)
              INTO ln_vat_amount
              FROM apps.xxcp_ic_inv_lines xil, apps.xxcp_ic_inv_header xih
             WHERE     1 = 1
                   AND xih.invoice_header_id = xil.invoice_header_id
                   AND xih.invoice_header_id = p_invoice_id
                   AND xih.attribute2 = p_company
                   AND xil.attribute10 IN ('S', 'O')
                   AND xil.ic_tax_rate = p_ic_tax_rate;
        ELSE
            BEGIN
                SELECT net_amount
                  INTO ln_vat_amount
                  FROM (  SELECT ROUND (SUM (xil.quantity * xil.ic_unit_price), 2) net_amount, SUBSTR (description, 1, (INSTR (description, ':') - 1)) natura_code
                            FROM apps.xxcp_ic_inv_lines xil, apps.xxcp_ic_inv_header xih, fnd_lookup_Values flv
                           WHERE     1 = 1
                                 AND xih.invoice_header_id =
                                     xil.invoice_header_id
                                 AND xih.invoice_header_id = p_invoice_id
                                 AND xih.attribute2 = p_company
                                 AND xil.attribute10 IN ('S', 'O')
                                 AND xil.ic_tax_rate = p_ic_tax_rate
                                 AND xil.ic_tax_code = flv.lookup_code
                                 AND flv.lookup_type =
                                     'XXD_ARIC_VT_TAX_CODE_MAPPING'
                                 AND flv.enabled_flag = 'Y'
                                 AND SYSDATE BETWEEN NVL (
                                                         flv.start_date_Active,
                                                         SYSDATE)
                                                 AND NVL (flv.end_date_active,
                                                          SYSDATE + 1)
                                 AND flv.language = 'US'
                        GROUP BY description)
                 WHERE     1 = 1
                       AND natura_code =
                           (SELECT SUBSTR (fl.description, 1, (INSTR (fl.description, ':') - 1))
                              FROM fnd_lookup_values fl
                             WHERE     1 = 1
                                   AND fl.language = 'US'
                                   AND fl.enabled_flag = 'Y'
                                   AND SYSDATE BETWEEN NVL (
                                                           fl.start_date_Active,
                                                           SYSDATE)
                                                   AND NVL (
                                                           fl.end_date_active,
                                                           SYSDATE + 1)
                                   AND fl.lookup_type =
                                       'XXD_ARIC_VT_TAX_CODE_MAPPING'
                                   AND fl.lookup_code = p_tax_code);
            EXCEPTION
                WHEN OTHERS
                THEN
                    RETURN 0;
            END;
        END IF;

        RETURN ln_vat_amount;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_log ('Error occured while fectching get_vat_net_amount  ');
            RETURN 0;
    END get_vat_net_amount;

    FUNCTION get_ap_vat_net_amount (p_company IN VARCHAR2, p_invoice_id IN NUMBER, p_ic_tax_rate IN NUMBER
                                    , p_ic_category IN VARCHAR2)
        RETURN NUMBER
    IS
        ln_vat_amount   NUMBER;
    BEGIN
        IF p_ic_tax_rate <> 0
        THEN
            IF p_ic_category IN ('VT Manual', 'VT Inventory')
            THEN
                BEGIN
                    SELECT ROUND (SUM (xil.quantity * xil.ic_unit_price), 2)
                      INTO ln_vat_amount
                      FROM apps.xxcp_ic_inv_lines xil, apps.xxcp_ic_inv_header xih, apps.xxcp_process_history xph
                     WHERE     1 = 1
                           AND xih.invoice_header_id = xil.invoice_header_id
                           AND xih.invoice_header_id = p_invoice_id
                           AND xih.attribute3 = p_company
                           AND xil.attribute_id = xph.attribute_id
                           AND xph.status = 'GLI'
                           AND xph.segment6 IN ('11901', '11902')
                           AND xil.attribute10 IN ('S', 'O')
                           AND (xph.attribute5 * 100) = p_ic_tax_rate;

                    IF ln_vat_amount IS NULL
                    THEN
                        SELECT ROUND (SUM (xil.quantity * xil.ic_unit_price), 2)
                          INTO ln_vat_amount
                          FROM apps.xxcp_ic_inv_lines xil, apps.xxcp_ic_inv_header xih, apps.xxcp_process_history xph
                         WHERE     1 = 1
                               AND xih.invoice_header_id =
                                   xil.invoice_header_id
                               AND xih.invoice_header_id = p_invoice_id
                               AND xih.attribute3 = p_company
                               AND xil.attribute_id = xph.attribute_id
                               AND xph.status = 'GLI'
                               AND xil.attribute10 IN ('S', 'O')
                               AND (xph.attribute5 * 100) = p_ic_tax_rate;
                    END IF;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        SELECT ROUND (SUM (xil.quantity * xil.ic_unit_price), 2)
                          INTO ln_vat_amount
                          FROM apps.xxcp_ic_inv_lines xil, apps.xxcp_ic_inv_header xih, apps.xxcp_process_history xph
                         WHERE     1 = 1
                               AND xih.invoice_header_id =
                                   xil.invoice_header_id
                               AND xih.invoice_header_id = p_invoice_id
                               AND xih.attribute3 = p_company
                               AND xil.attribute_id = xph.attribute_id
                               AND xph.status = 'GLI'
                               AND xil.attribute10 IN ('S', 'O')
                               AND (xph.attribute5 * 100) = p_ic_tax_rate;

                        RETURN ln_vat_amount;
                END;
            ELSIF p_ic_category IN
                      ('VT Fixed Assets', 'VT projects', 'VT Payables')
            THEN
                BEGIN
                    SELECT ROUND (SUM (xil.quantity * xil.ic_unit_price), 2)
                      INTO ln_vat_amount
                      FROM apps.xxcp_ic_inv_lines xil, apps.xxcp_ic_inv_header xih, apps.xxcp_process_history xph
                     WHERE     1 = 1
                           AND xih.invoice_header_id = xil.invoice_header_id
                           AND xih.invoice_header_id = p_invoice_id
                           AND xih.attribute3 = p_company
                           AND xil.attribute_id = xph.attribute_id
                           AND xph.status = 'GLI'
                           AND xph.segment6 IN ('11901', '11902')
                           AND xil.attribute10 IN ('S', 'O')
                           AND (xph.attribute4 * 100) = p_ic_tax_rate;

                    IF ln_vat_amount IS NULL
                    THEN
                        SELECT ROUND (SUM (xil.quantity * xil.ic_unit_price), 2)
                          INTO ln_vat_amount
                          FROM apps.xxcp_ic_inv_lines xil, apps.xxcp_ic_inv_header xih, apps.xxcp_process_history xph
                         WHERE     1 = 1
                               AND xih.invoice_header_id =
                                   xil.invoice_header_id
                               AND xih.invoice_header_id = p_invoice_id
                               AND xih.attribute3 = p_company
                               AND xil.attribute_id = xph.attribute_id
                               AND xph.status = 'GLI'
                               AND xil.attribute10 IN ('S', 'O')
                               AND (xph.attribute4 * 100) = p_ic_tax_rate;
                    END IF;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        SELECT ROUND (SUM (xil.quantity * xil.ic_unit_price), 2)
                          INTO ln_vat_amount
                          FROM apps.xxcp_ic_inv_lines xil, apps.xxcp_ic_inv_header xih, apps.xxcp_process_history xph
                         WHERE     1 = 1
                               AND xih.invoice_header_id =
                                   xil.invoice_header_id
                               AND xih.invoice_header_id = p_invoice_id
                               AND xih.attribute3 = p_company
                               AND xil.attribute_id = xph.attribute_id
                               AND xph.status = 'GLI'
                               AND xil.attribute10 IN ('S', 'O')
                               AND (xph.attribute4 * 100) = p_ic_tax_rate;

                        RETURN ln_vat_amount;
                END;
            ELSE
                BEGIN
                    SELECT ROUND (SUM (xil.quantity * xil.ic_unit_price), 2)
                      INTO ln_vat_amount
                      FROM apps.xxcp_ic_inv_lines xil, apps.xxcp_ic_inv_header xih, apps.xxcp_process_history xph
                     WHERE     1 = 1
                           AND xih.invoice_header_id = xil.invoice_header_id
                           AND xih.invoice_header_id = p_invoice_id
                           AND xih.attribute3 = p_company
                           AND xil.attribute_id = xph.attribute_id
                           AND xph.status = 'GLI'
                           AND xph.segment6 IN ('11901', '11902')
                           AND xil.attribute10 IN ('S', 'O')
                           AND (xph.attribute5 * 100) = p_ic_tax_rate;

                    IF ln_vat_amount IS NULL
                    THEN
                        SELECT ROUND (SUM (xil.quantity * xil.ic_unit_price), 2)
                          INTO ln_vat_amount
                          FROM apps.xxcp_ic_inv_lines xil, apps.xxcp_ic_inv_header xih, apps.xxcp_process_history xph
                         WHERE     1 = 1
                               AND xih.invoice_header_id =
                                   xil.invoice_header_id
                               AND xih.invoice_header_id = p_invoice_id
                               AND xih.attribute3 = p_company
                               AND xil.attribute_id = xph.attribute_id
                               AND xph.status = 'GLI'
                               AND xil.attribute10 IN ('S', 'O')
                               AND (xph.attribute5 * 100) = p_ic_tax_rate;
                    END IF;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        SELECT ROUND (SUM (xil.quantity * xil.ic_unit_price), 2)
                          INTO ln_vat_amount
                          FROM apps.xxcp_ic_inv_lines xil, apps.xxcp_ic_inv_header xih, apps.xxcp_process_history xph
                         WHERE     1 = 1
                               AND xih.invoice_header_id =
                                   xil.invoice_header_id
                               AND xih.invoice_header_id = p_invoice_id
                               AND xih.attribute3 = p_company
                               AND xil.attribute_id = xph.attribute_id
                               AND xph.status = 'GLI'
                               AND xil.attribute10 IN ('S', 'O')
                               AND (xph.attribute5 * 100) = p_ic_tax_rate;

                        RETURN ln_vat_amount;
                END;
            END IF;
        ELSIF p_ic_tax_rate = 0
        THEN
            SELECT ROUND (SUM (xil.quantity * xil.ic_unit_price), 2)
              INTO ln_vat_amount
              FROM apps.xxcp_ic_inv_lines xil
             WHERE     xil.invoice_header_id = p_invoice_id
                   AND xil.attribute10 IN ('S', 'O');
        END IF;

        RETURN ln_vat_amount;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_log ('Error occured while fectching get_vat_net_amount  ');
            RETURN 0;
    END get_ap_vat_net_amount;

    PROCEDURE get_constant_values (pv_company              IN     VARCHAR2,
                                   xv_company_reg_number      OUT VARCHAR2,
                                   xv_liquidation_status      OUT VARCHAR2,
                                   xv_share_capital           OUT VARCHAR2,
                                   xv_status_share            OUT VARCHAR2)
    AS
        CURSOR c_cons IS
            SELECT ffv.attribute1 field_name, ffv.attribute3 field_value
              FROM fnd_flex_value_sets ffvs, fnd_flex_values ffv
             WHERE     1 = 1
                   AND ffvs.flex_value_set_id = ffv.flex_value_set_id
                   AND ffvs.flex_value_set_name =
                       'XXD_AR_IC_DEFAULT_VALUES_VS'
                   AND ffv.enabled_flag = 'Y'
                   AND SYSDATE BETWEEN NVL (ffv.start_date_Active, SYSDATE)
                                   AND NVL (ffv.end_date_active, SYSDATE + 1)
                   AND ffv.attribute2 = pv_company;

        lv_company_reg_number   VARCHAR2 (30);
        lv_liquidation_status   VARCHAR2 (30);
        lv_share_capital        VARCHAR2 (30);
        lv_status_share         VARCHAR2 (30);
        lv_seller_email         VARCHAR2 (30);
        lv_seller_fax           VARCHAR2 (30);
        lv_seller_tel           VARCHAR2 (30);
    BEGIN
        FOR i IN c_cons
        LOOP
            IF i.field_name = 'COMPANY_REG_NUMBER'
            THEN
                xv_company_reg_number   := i.field_value;
            ELSIF i.field_name = 'LIQUIDATION_STATUS'
            THEN
                xv_liquidation_status   := i.field_value;
            ELSIF i.field_name = 'SHARE_CAPITAL'
            THEN
                xv_share_capital   := i.field_value;
            ELSIF i.field_name = 'STATUS_SHAREHOLDERS'
            THEN
                xv_status_share   := i.field_value;
            END IF;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_log ('Error in fetching get_constant_values :' || SQLERRM);
            xv_company_reg_number   := NULL;
            xv_liquidation_status   := NULL;
            xv_share_capital        := NULL;
            xv_status_share         := NULL;
    END get_constant_values;

    FUNCTION get_routing_code (pv_company VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_routing_code   VARCHAR2 (30);
    BEGIN
        SELECT lookup_code
          INTO lv_routing_code
          FROM fnd_lookup_values
         WHERE     lookup_type = 'XXD_AR_IC_VT_ROUTING_CODE'
               AND language = 'US'
               AND enabled_flag = 'Y'
               AND SYSDATE BETWEEN NVL (start_date_Active, SYSDATE)
                               AND NVL (end_date_active, SYSDATE + 1)
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
               AND lookup_type = 'XXD_AR_INTERCO_SEND_TO_SDI'
               AND enabled_flag = 'Y'
               AND SYSDATE BETWEEN NVL (start_date_active, SYSDATE)
                               AND NVL (end_date_active, SYSDATE)
               AND attribute_category = 'XXD_AR_INTERCO_SEND_TO_SDI'
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

    FUNCTION get_h_tot_net_amount (p_company      IN VARCHAR2,
                                   p_invoice_id   IN NUMBER)
        RETURN NUMBER
    IS
        ln_net_amount   NUMBER;
    BEGIN
        SELECT SUM (xil.quantity * xil.ic_unit_price)
          INTO ln_net_amount
          FROM apps.xxcp_ic_inv_lines xil, apps.xxcp_ic_inv_header xih
         WHERE     1 = 1
               AND xih.invoice_header_id = xil.invoice_header_id
               AND xih.invoice_header_id = p_invoice_id
               AND xih.attribute2 = p_company
               AND xil.attribute10 IN ('S', 'O');

        RETURN ln_net_amount;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_log ('Error occured while fectching get_net_amount  ');
            RETURN 0;
    END get_h_tot_net_amount;

    FUNCTION get_ap_h_tot_net_amount (p_company      IN VARCHAR2,
                                      p_invoice_id   IN NUMBER)
        RETURN NUMBER
    IS
        ln_net_amount   NUMBER;
    BEGIN
        SELECT SUM (xil.quantity * xil.ic_unit_price)
          INTO ln_net_amount
          FROM apps.xxcp_ic_inv_lines xil, apps.xxcp_ic_inv_header xih
         WHERE     1 = 1
               AND xih.invoice_header_id = xil.invoice_header_id
               AND xih.invoice_header_id = p_invoice_id
               AND xih.attribute3 = p_company
               AND xil.attribute10 IN ('S', 'O');

        RETURN ln_net_amount;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_log ('Error occured while fectching get_net_amount  ');
            RETURN 0;
    END get_ap_h_tot_net_amount;


    FUNCTION get_h_tot_tax_amount (p_company      IN VARCHAR2,
                                   p_invoice_id   IN NUMBER)
        RETURN NUMBER
    IS
        ln_tax_amount   NUMBER;
    BEGIN
        SELECT SUM (xi.quantity * xi.ic_tax_amount)
          INTO ln_tax_amount
          FROM apps.xxcp_ic_inv_lines xi, apps.xxcp_ic_inv_header xh
         WHERE     1 = 1
               AND xh.invoice_header_id = xi.invoice_header_id
               AND xh.invoice_header_id = p_invoice_id
               AND xi.attribute10 IN ('S', 'O')
               AND xh.attribute2 = p_company;

        RETURN ln_tax_amount;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_log (
                'Error occured while fectching get_h_tot_tax_amount  ');
            RETURN 0;
    END get_h_tot_tax_amount;

    FUNCTION get_ap_h_tot_tax_amount (p_company IN VARCHAR2, p_invoice_id IN NUMBER, p_attribute_id IN NUMBER)
        RETURN NUMBER
    IS
        ln_net_amount   NUMBER;
    BEGIN
        SELECT SUM (NVL (entered_dr, entered_cr))
          INTO ln_net_amount
          FROM apps.xxcp_process_history ph, apps.xxcp_ic_inv_lines xils
         WHERE     ph.attribute_id = xils.attribute_id
               AND xils.invoice_header_id = p_invoice_id
               AND xils.attribute10 IN ('S', 'O')
               AND NOT EXISTS
                       (SELECT 1
                          FROM xxcp_account_rules xar
                         WHERE     NVL (xar.rule_category_1, 'X') = 'REVERSE'
                               AND xar.rule_id = xils.transaction_rule_id)
               AND ph.segment1 = p_company
               AND ph.status = 'GLI'
               AND ph.segment6 IN ('11901', '11902');

        RETURN ln_net_amount;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_log ('Error occured while fectching get_net_amount  ');
            RETURN 0;
    END get_ap_h_tot_tax_amount;

    FUNCTION get_document_type (p_ic_tax_code IN VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_doc_type   VARCHAR2 (30);
    BEGIN
        SELECT tag
          INTO lv_doc_type
          FROM fnd_lookup_values
         WHERE     language = 'US'
               AND ROWNUM = 1
               AND enabled_flag = 'Y'
               AND SYSDATE BETWEEN NVL (start_date_Active, SYSDATE)
                               AND NVL (end_date_active, SYSDATE + 1)
               AND lookup_type = 'XXD_APIC_VT_TAX_CODE_MAPPING' -- 'XXD_APIC_TD_TAX_CODE_MAPPING'
               AND lookup_code = NVL (p_ic_tax_code, 'NULL');

        RETURN lv_doc_type;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_log ('Error occured while fectching get_document_type  ');
            RETURN NULL;
    END get_document_type;

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
               AND aila.org_id = p_org_id;

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
            SELECT DISTINCT invoice_number, invoice_id, company,
                            invoice_date, invoice_currency_code, conc_request_id,
                            file_name
              FROM xxdo.xxd_ar_ic_inv_stg
             WHERE conc_request_id = p_conc_request_id AND process_flag = 'Y';

        CURSOR cur_inv_details (p_invoice_id NUMBER, pv_conc_request_id NUMBER, pv_Company VARCHAR2)
        IS
            SELECT DECODE (get_lookup_value ('INVOICE_ID', pv_Company), 'Y', STG.INVOICE_ID, '') || '|' || DECODE (get_lookup_value ('INVOICE_NUMBER', pv_Company), 'Y', STG.INVOICE_NUMBER, '') || '|' || DECODE (get_lookup_value ('INVOICE_DATE', pv_Company), 'Y', TO_CHAR (STG.INVOICE_DATE, 'DD-MON-YYYY'), '') || '|' || DECODE (get_lookup_value ('PAYMENT_DUE_DATE', pv_Company), 'Y', TO_CHAR (STG.PAYMENT_DUE_DATE, 'DD-MON-YYYY'), '') || '|' || DECODE (get_lookup_value ('PAYMENT_TERM', pv_Company), 'Y', TO_CHAR (STG.PAYMENT_DUE_DATE, 'DD-MON-YYYY'), '') || '|' || DECODE (get_lookup_value ('INVOICE_CURRENCY_CODE', pv_Company), 'Y', STG.INVOICE_CURRENCY_CODE, '') || '|' || DECODE (get_lookup_value ('DOCUMENT_TYPE', pv_Company), 'Y', STG.DOCUMENT_TYPE, '') --   ||'|'||
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        --    DECODE(get_lookup_value('DUTY_STAMP',pv_Company),'Y',STG.DUTY_STAMP,'')
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        || '|' || DECODE (get_lookup_value ('INVOICE_DOC_REFERENCE', pv_Company), 'Y', STG.INVOICE_DOC_REFERENCE, '') || '|' || DECODE (get_lookup_value ('INV_DOC_REF_DESC', pv_Company), 'Y', STG.INV_DOC_REF_DESC, '') || '|' || DECODE (get_lookup_value ('LEGAL_ENTITY_NAME', pv_Company), 'Y', STG.LEGAL_ENTITY_NAME, '') || '|' || DECODE (get_lookup_value ('LEGAL_ENTITY_ADDRESS_STREET', pv_Company), 'Y', STG.LEGAL_ENTITY_ADDRESS_STREET, '') || '|' || DECODE (get_lookup_value ('LEGAL_ENTITY_ADDRESS_POSTAL_CODE', pv_Company), 'Y', STG.LEGAL_ENTITY_ADDRESS_POSTAL_CODE, '') || '|' || DECODE (get_lookup_value ('LEGAL_ENTITY_ADDRESS_CITY', pv_Company), 'Y', STG.LEGAL_ENTITY_ADDRESS_CITY, '') || '|' || DECODE (get_lookup_value ('LEGAL_ENTITY_ADDRESS_PROVINCE', pv_Company), 'Y', STG.LEGAL_ENTITY_ADDRESS_PROVINCE, '') || '|' || DECODE (get_lookup_value ('LEGAL_ENTITY_COUNTRY', pv_Company), 'Y', STG.LEGAL_ENTITY_COUNTRY, '') || '|' || DECODE (get_lookup_value ('LEGAL_ENTITY_COUNTRY_CODE', pv_Company), 'Y', STG.LEGAL_ENTITY_COUNTRY_CODE, '') || '|' || DECODE (get_lookup_value ('LE_VAT_NUMBER', pv_Company), 'Y', STG.LE_VAT_NUMBER, '') || '|' || DECODE (get_lookup_value ('LE_REGISTRIATION_NUMBER', pv_Company), 'Y', STG.LE_REGISTRIATION_NUMBER, '') || '|' || DECODE (get_lookup_value ('PROVINCE_REG_OFFICE', pv_Company), 'Y', STG.PROVINCE_REG_OFFICE, '') || '|' || DECODE (get_lookup_value ('COMPANY_REG_NUMBER', pv_Company), 'Y', STG.COMPANY_REG_NUMBER, '') || '|' || DECODE (get_lookup_value ('SHARE_CAPITAL', pv_Company), 'Y', STG.SHARE_CAPITAL, '') || '|' || DECODE (get_lookup_value ('STATUS_SHAREHOLDERS', pv_Company), 'Y', STG.STATUS_SHAREHOLDERS, '') || '|' || DECODE (get_lookup_value ('LIQUIDATION_STATUS', pv_Company), 'Y', STG.LIQUIDATION_STATUS, '') || '|' || DECODE (get_lookup_value ('BUYER_NAME', pv_Company), 'Y', STG.BUYER_NAME, '') || '|' || DECODE (get_lookup_value ('BUYER_ADDRESS_STREET', pv_Company), 'Y', STG.BUYER_ADDRESS_STREET, '') || '|' || DECODE (get_lookup_value ('BUYER_ADDRESS_POSTAL_CODE', pv_Company), 'Y', STG.BUYER_ADDRESS_POSTAL_CODE, '') || '|' || DECODE (get_lookup_value ('BUYER_ADDRESS_CITY', pv_Company), 'Y', STG.BUYER_ADDRESS_CITY, '') || '|' || DECODE (get_lookup_value ('BUYER_ADDRESS_PROVINCE', pv_Company), 'Y', STG.BUYER_ADDRESS_PROVINCE, '') || '|' || DECODE (get_lookup_value ('BUYER_ADDRESS_COUNTRY', pv_Company), 'Y', STG.BUYER_ADDRESS_COUNTRY, '') || '|' || DECODE (get_lookup_value ('BUYER_ADDRESS_COUNTRY_CODE', pv_Company), 'Y', STG.BUYER_ADDRESS_COUNTRY_CODE, '') || '|' || DECODE (get_lookup_value ('BUYER_VAT_NUMBER', pv_Company), 'Y', STG.BUYER_VAT_NUMBER, '') || '|' || DECODE (get_lookup_value ('BUYER_BUSINESS_REGISTRATION_NUMBER', pv_Company), 'Y', STG.BUYER_BUSINESS_REGISTRATION_NUMBER, '') || '|' || DECODE (get_lookup_value ('ROUTING_CODE', pv_Company), 'Y', STG.ROUTING_CODE, '') || '|' || DECODE (get_lookup_value ('H_TOTAL_TAX_AMOUNT', pv_Company), 'Y', STG.H_TOTAL_TAX_AMOUNT, '') || '|' || DECODE (get_lookup_value ('H_TOTAL_NET_AMOUNT', pv_Company), 'Y', STG.H_TOTAL_NET_AMOUNT, '') || '|' || DECODE (get_lookup_value ('H_TOTAL_NET_AMOUNT_INCLUDING_DISCOUNT_CHARGES', pv_Company), 'Y', STG.H_TOTAL_NET_AMOUNT_INCLUDING_DISCOUNT_CHARGES, '') || '|' || DECODE (get_lookup_value ('H_INVOICE_TOTAL', pv_Company), 'Y', STG.H_INVOICE_TOTAL, '') || '|' || DECODE (get_lookup_value ('VAT_NET_AMOUNT', pv_Company), 'Y', STG.VAT_NET_AMOUNT, '') || '|' || DECODE (get_lookup_value ('VAT_RATE', pv_Company), 'Y', STG.VAT_RATE, '') || '|' || DECODE (get_lookup_value ('VAT_AMOUNT', pv_Company), 'Y', STG.VAT_AMOUNT, '') || '|' || DECODE (get_lookup_value ('TAX_CODE', pv_Company),  'Y', STG.TAX_CODE,  'C', STG.TAX_CODE,  '') || '|' || DECODE (get_lookup_value ('TAX_EXEMPTION_DESCRIPTION', pv_Company),  'Y', STG.TAX_EXEMPTION_DESCRIPTION,  'C', STG.TAX_EXEMPTION_DESCRIPTION,  '') || '|' || DECODE (get_lookup_value ('INVOICE_DESCRIPTION', pv_Company), 'Y', STG.Invoice_Description, '') || '|' || DECODE (get_lookup_value ('UNIT_OF_MEASURE_CODE', pv_Company), 'Y', STG.UNIT_OF_MEASURE_CODE, '') || '|' || DECODE (get_lookup_value ('QUANTITY_INVOICED', pv_Company), 'Y', STG.QUANTITY_INVOICED, '') || '|' || DECODE (get_lookup_value ('UNIT_PRICE', pv_Company), 'Y', STG.UNIT_PRICE, '') || '|' || DECODE (get_lookup_value ('L_VAT_AMOUNT', pv_Company), 'Y', STG.L_VAT_AMOUNT, '') || '|' || DECODE (get_lookup_value ('L_TAX_RATE', pv_Company), 'Y', STG.L_TAX_RATE, '') || '|' || DECODE (get_lookup_value ('L_TAX_EXEMPTION_CODE', pv_Company),  'Y', STG.L_TAX_EXEMPTION_CODE,  'C', STG.L_TAX_EXEMPTION_CODE,  '') || '|' || DECODE (get_lookup_value ('L_NET_AMOUNT', pv_Company), 'Y', STG.L_NET_AMOUNT, '') || '|' || DECODE (get_lookup_value ('H_DISCOUNT_AMOUNT', pv_Company), 'Y', STG.H_DISCOUNT_AMOUNT, '') || '|' || DECODE (get_lookup_value ('H_DISCOUNT_DESCRIPTION', pv_Company), 'Y', STG.H_DISCOUNT_DESCRIPTION, '') || '|' || DECODE (get_lookup_value ('H_DISCOUNT_TAX_RATE', pv_Company), 'Y', STG.H_DISCOUNT_TAX_RATE, '') || '|' || DECODE (get_lookup_value ('H_CHARGE_AMOUNT', pv_Company), 'Y', STG.H_CHARGE_AMOUNT, '') || '|' || DECODE (get_lookup_value ('H_CHARGE_DESCRIPTION', pv_Company), 'Y', STG.H_CHARGE_DESCRIPTION, '') || '|' || DECODE (get_lookup_value ('H_CHARGE_TAX_RATE', pv_Company), 'Y', STG.H_CHARGE_TAX_RATE, '') || '|' || DECODE (get_lookup_value ('L_DISCOUNT_AMOUNT', pv_Company), 'Y', STG.L_DISCOUNT_AMOUNT, '') || '|' || DECODE (get_lookup_value ('L_DISCOUNT_DESCRIPTION', pv_Company), 'Y', STG.L_DISCOUNT_DESCRIPTION, '') || '|' || DECODE (get_lookup_value ('L_CHARGE_AMOUNT', pv_Company), 'Y', STG.L_CHARGE_AMOUNT, '') || '|' || DECODE (get_lookup_value ('L_CHARGE_DESCRIPTION', pv_Company), 'Y', STG.L_CHARGE_DESCRIPTION, '') || '|' || DECODE (get_lookup_value ('L_DESCRIPTION_GOODS', pv_Company), 'Y', STG.L_DESCRIPTION_GOODS, '') || '|' || DECODE (get_lookup_value ('EXCHANGE_RATE', pv_Company), 'Y', STG.EXCHANGE_RATE, '') || '|' || DECODE (get_lookup_value ('EXCHANGE_DATE', pv_Company), 'Y', TO_CHAR (STG.EXCHANGE_DATE, 'DD-MON-YYYY'), '') || '|' || DECODE (get_lookup_value ('ORIGINAL_CURRENCY_CODE', pv_Company), 'Y', STG.ORIGINAL_CURRENCY_CODE, '') line
              FROM XXDO.XXD_AR_IC_INV_STG STG
             WHERE     1 = 1
                   AND conc_request_id = pv_conc_request_id
                   AND process_flag = 'Y'
                   AND invoice_id = p_invoice_id;

        CURSOR ap_failed_msgs_cur IS
              SELECT UNIQUE hdr.invoice_number, hdr.invoice_date, hdr.invoice_currency_code,
                            hdr.h_invoice_total, er.ERROR_CODE, er.error_message
                FROM xxdo.xxd_ar_ic_inv_stg hdr, xxdo.xxd_ar_ic_inv_errors_gt er
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
              FROM xxdo.xxd_ar_ic_inv_stg
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
                get_email_ids ('XXD_AR_IC_INV_EMAIL_NOTIF_LKP', lv_inst_name);


            apps.do_mail_utils.send_mail_header ('erp@deckers.com', gv_def_mail_recips, 'Deckers AR Intercompany Invoice Extract Report ' || ' Email generated from ' || lv_inst_name || ' instance'
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
                'Please see attached Deckers AR Intercompany Invoice Extract Report.',
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
                --     ||'DUTY_STAMP'
                --   || '|'
                || 'INVOICE_DOC_REFERENCE'
                || '|'
                || 'INV_DOC_REF_DESC'
                || '|'
                || 'LEGAL_ENTITY_NAME'
                || '|'
                || 'LEGAL_ENTITY_ADDRESS_STREET'
                || '|'
                || 'LEGAL_ENTITY_ADDRESS_POSTAL_CODE'
                || '|'
                || 'LEGAL_ENTITY_ADDRESS_CITY'
                || '|'
                || 'LEGAL_ENTITY_ADDRESS_PROVINCE'
                || '|'
                || 'LEGAL_ENTITY_COUNTRY'
                || '|'
                || 'LEGAL_ENTITY_COUNTRY_CODE'
                || '|'
                || 'LE_VAT_NUMBER'
                || '|'
                || 'LE_REGISTRIATION_NUMBER'
                || '|'
                || 'PROVINCE_REG_OFFICE'
                || '|'
                || 'COMPANY_REG_NUMBER'
                || '|'
                || 'SHARE_CAPITAL'
                || '|'
                || 'STATUS_SHAREHOLDERS'
                || '|'
                || 'LIQUIDATION_STATUS'
                || '|'
                || 'BUYER_NAME'
                || '|'
                || 'BUYER_ADDRESS_STREET'
                || '|'
                || 'BUYER_ADDRESS_POSTAL_CODE'
                || '|'
                || 'BUYER_ADDRESS_CITY'
                || '|'
                || 'BUYER_ADDRESS_PROVINCE'
                || '|'
                || 'BUYER_ADDRESS_COUNTRY'
                || '|'
                || 'BUYER_ADDRESS_COUNTRY_CODE'
                || '|'
                || 'BUYER_VAT_NUMBER'
                || '|'
                || 'BUYER_BUSINESS_REGISTRATION_NUMBER'
                || '|'
                || 'ROUTING_CODE'
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
                || 'TAX_EXEMPTION_DESCRIPTION'
                || '|'
                || 'INVOICE_DESCRIPTION'
                || '|'
                || 'UNIT_OF_MEASURE_CODE'
                || '|'
                || 'QUANTITY_INVOICED'
                || '|'
                || 'UNIT_PRICE'
                || '|'
                || 'L_VAT_AMOUNT'
                || '|'
                || 'L_TAX_RATE'
                || '|'
                || 'L_TAX_EXEMPTION_CODE'
                || '|'
                || 'L_NET_AMOUNT'
                || '|'
                || 'H_DISCOUNT_AMOUNT'
                || '|'
                || 'H_DISCOUNT_DESCRIPTION'
                || '|'
                || 'H_DISCOUNT_TAX_RATE'
                || '|'
                || 'H_CHARGE_AMOUNT'
                || '|'
                || 'H_CHARGE_DESCRIPTION'
                || '|'
                || 'H_CHARGE_TAX_RATE'
                || '|'
                || 'L_DISCOUNT_AMOUNT'
                || '|'
                || 'L_DISCOUNT_DESCRIPTION'
                || '|'
                || 'L_CHARGE_AMOUNT'
                || '|'
                || 'L_CHARGE_DESCRIPTION'
                || '|'
                || 'L_DESCRIPTION_GOODS'
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

                FOR j
                    IN cur_inv_details (i.invoice_id,
                                        i.conc_request_id,
                                        i.company)
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
              FROM xxdo.xxd_ar_ic_inv_stg
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
                get_email_ids ('XXD_AR_IC_ERR_EMAIL_NOTIF_LKP', lv_inst_name);


            apps.do_mail_utils.send_mail_header ('erp@deckers.com', gv_def_mail_recips, 'Deckers AR Intercompany Invoice Error Report ' || ' Email generated from ' || lv_inst_name || ' instance'
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
                'Please see attached Deckers AR Intercompany Invoice Error Report.',
                ln_ret_val);
            do_mail_utils.send_mail_line ('', ln_ret_val);
            do_mail_utils.send_mail_line (
                'Note: This is auto generated mail, please donot reply.',
                ln_ret_val);
            do_mail_utils.send_mail_line ('--boundarystring', ln_ret_val);
            do_mail_utils.send_mail_line ('Content-Type: text/xls',
                                          ln_ret_val);
            do_mail_utils.send_mail_line (
                   'Content-Disposition: attachment; filename="Deckers_AR_Intercompany_error_'
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
                               'XXD_AP_IC_ERROR_MESSAGES_VS'
                           AND ffv.enabled_flag = 'Y'
                           AND SYSDATE BETWEEN NVL (ffv.start_date_Active,
                                                    SYSDATE)
                                           AND NVL (ffv.end_date_active,
                                                    SYSDATE + 1)
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

    PROCEDURE insert_ar_eligible_recs (pv_company_segment IN VARCHAR2, pv_reprocess_flag IN VARCHAR2, pv_invoice_num IN NUMBER, pv_from_date IN VARCHAR2, pv_to_date IN VARCHAR2, x_ret_code OUT VARCHAR2
                                       , x_ret_message OUT VARCHAR2)
    IS
        CURSOR cur_inv (p_company_segment IN VARCHAR2, pv_invoice_num IN NUMBER, pv_from_date IN VARCHAR2
                        , pv_to_date IN VARCHAR2)
        IS
            SELECT xih.invoice_header_id
                       invoice_id,
                   xih.invoice_number,
                   xih.invoice_date,
                   (xih.invoice_date + 90)
                       payment_due_date,
                   apt.name
                       payment_term,
                   xih.attribute2
                       company,
                   xih.invoice_currency
                       invoice_currency_code,
                   xil.attribute_id,
                   xih.invoice_class,
                   DECODE (xih.invoice_class,
                           'CM', 'TD04',
                           'INV', 'TD01',
                           'DM', 'TD05',
                           NULL)
                       document_type,
                   NULL
                       duty_stamp,
                   NULL
                       invoice_doc_reference,
                   NULL
                       inv_doc_ref_desc,
                   seller.bill_to_name
                       LEGAL_ENTITY_NAME,
                   seller.bill_to_address_line_1
                       LEGAL_ENTITY_ADDRESS_STREET,
                   seller.bill_to_postal_code
                       LEGAL_ENTITY_ADDRESS_POSTAL_CODE,
                   seller.bill_to_town_or_city
                       LEGAL_ENTITY_ADDRESS_CITY,
                   seller.bill_to_region
                       LEGAL_ENTITY_ADDRESS_PROVINCE,
                   seller.bill_to_country
                       LEGAL_ENTITY_COUNTRY,
                   seller.bill_to_country_code
                       LEGAL_ENTITY_COUNTRY_CODE,
                   xih.attribute4
                       LE_VAT_NUMBER,
                   xih.attribute4
                       le_registriation_number,
                   NULL
                       province_reg_office,
                   NULL
                       company_reg_number,
                   NULL
                       share_capital,
                   NULL
                       status_shareholders,
                   NULL
                       liquidation_status,
                   cust.bill_to_name
                       buyer_name,
                   cust.bill_to_address_line_1
                       buyer_address_street,
                   cust.bill_to_postal_code
                       buyer_address_postal_code,
                   cust.bill_to_town_or_city
                       buyer_address_city,
                   cust.bill_to_region
                       buyer_address_province,
                   cust.bill_to_country
                       buyer_address_country,
                   cust.bill_to_country_code
                       buyer_address_country_code,
                   xih.attribute5
                       buyer_vat_registration_number,
                   xih.attribute5
                       buyer_business_registration_number,
                   DECODE (
                       xil.ic_tax_code,
                       'SUPPRESS', 0,
                       get_h_tot_tax_amount (xih.attribute2,
                                             xih.invoice_header_id))
                       h_total_tax_amount,
                   get_routing_code (xih.attribute2)
                       routing_code,
                   get_h_tot_net_amount (xih.attribute2,
                                         xih.invoice_header_id)
                       h_total_net_amount,
                   get_h_tot_net_amount (xih.attribute2,
                                         xih.invoice_header_id)
                       h_total_net_amount_including_discount_charges,
                   NULL
                       h_invoice_total,
                   get_vat_net_amount (xih.attribute2, xih.invoice_header_id, xil.ic_tax_rate
                                       , xil.ic_tax_code)
                       vat_net_amount,
                   xil.ic_tax_rate
                       vat_rate,
                   get_vat_amount (xih.attribute2, xih.invoice_header_id, xil.ic_tax_rate
                                   , xil.ic_tax_code)
                       vat_amount,
                   xil.ic_tax_code
                       tax_code,
                   (SELECT attribute2
                      FROM xxcp_cust_data
                     WHERE     1 = 1
                           AND category_name = 'ONESOURCE TAX CODES MAPPING'
                           AND attribute1 = xil.ic_tax_code
                           AND ROWNUM = 1)
                       tax_classification,
                   NULL
                       tax_exemption_description,
                   NVL ((xil.attribute2), 'AR Intercompany Invoice')
                       invoice_description,
                   'EA'
                       unit_of_measure_code,
                   xil.quantity
                       quantity_invoiced,
                   xil.ic_unit_price
                       unit_price,
                   ROUND ((xil.quantity * xil.ic_tax_amount), 2)
                       l_vat_amount,
                   xil.ic_tax_rate
                       l_tax_rate,
                   NULL
                       l_tax_exemption_code,
                   (quantity * ic_price)
                       l_net_amount,
                   NULL
                       h_discount_amount,
                   NULL
                       h_discount_description,
                   NULL
                       h_discount_tax_rate,
                   NULL
                       h_charge_amount,
                   NULL
                       h_charge_description,
                   NULL
                       h_charge_tax_rate,
                   NULL
                       l_discount_amount,
                   NULL
                       l_discount_description,
                   NULL
                       l_charge_amount,
                   NULL
                       l_charge_description,
                   NULL
                       l_description_goods,
                   (SELECT ph.accounted_exch_rate
                      FROM xxcp_process_history ph
                     WHERE     ph.attribute_id = xil.attribute_id
                           AND ph.status = 'GLI'
                           AND ph.accounted_exch_rate IS NOT NULL
                           AND ROWNUM = 1)
                       exchange_rate,
                   (SELECT ph.accounting_date
                      FROM xxcp_process_history ph
                     WHERE     ph.attribute_id = xil.attribute_id
                           AND ph.status = 'GLI'
                           AND ph.accounting_date IS NOT NULL
                           AND ROWNUM = 1)
                       exchange_date,
                   NULL
                       original_currency_code,
                   (SELECT COUNT (*)
                      FROM xxcp_ic_inv_lines line
                     WHERE     line.attribute_id =
                               TO_NUMBER (xil.attribute12)
                           AND line.attribute10 = 'T')
                       tax_line_cnt
              FROM apps.xxcp_ic_inv_header xih, apps.xxcp_ic_inv_lines xil, xxcp_address_details seller,
                   xxcp_address_details cust, -- apps.xxcp_process_history ph,
                                              apps.ap_terms apt
             WHERE     1 = 1
                   AND xih.attribute2 = p_company_segment              --'580'
                   AND xih.invoice_header_id = xil.invoice_header_id
                   AND seller.address_id = xih.invoice_address_id
                   AND cust.address_id = xih.customer_address_id
                   AND xil.attribute10 IN ('O', 'S')
                   AND xih.payment_term_id = apt.term_id(+)
                   AND xih.invoice_header_id =
                       NVL (pv_invoice_num, xih.invoice_header_id)
                   AND NVL (xih.extract_flag, 'N') =
                       DECODE (pv_reprocess_flag, 'Y', 'Y', 'N')
                   AND xih.invoice_date BETWEEN NVL (pv_from_date,
                                                     xih.invoice_date)
                                            AND pv_to_date
                   AND NOT EXISTS
                           (SELECT 1
                              FROM xxcp_ic_inv_header hdr, xxcp_ic_inv_lines line, xxcp_process_history xph
                             WHERE     hdr.attribute2 = xih.attribute2
                                   AND hdr.invoice_class = 'CM'
                                   AND hdr.invoice_header_id =
                                       line.invoice_header_id
                                   AND hdr.invoice_header_id =
                                       xih.invoice_header_id
                                   AND line.invoice_line_id =
                                       xil.invoice_line_id
                                   AND line.ic_line_amount < 0
                                   AND line.attribute_id = xph.attribute_id
                                   AND xph.status = 'GLI'
                                   AND xph.category <> 'VT Inventory');


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
        lv_tax_code                  VARCHAR2 (100);
        lv_tax_codrate               VARCHAR2 (100);
        lv_tax_rate                  NUMBER;
        ln_cnt_attr3                 NUMBER;
        ln_cnt_attr4                 NUMBER;
        lv_final_tax_code            VARCHAR2 (100);
        lv_final_tax_rate            NUMBER;
        lv_document_type             VARCHAR2 (60);
        l_h_tot_amount               NUMBER;
        l_vat_net_amount             NUMBER;
        l_vat_amount                 NUMBER;
        lv_tax_exempt_desc           VARCHAR2 (4000) := NULL;
        lv_tax_exempt_code           VARCHAR2 (250) := NULL;
        lv_tax_classification        VARCHAR2 (100) := NULL;
        ld_tax_code                  VARCHAR2 (250);
        l_tax_line_cnt               NUMBER;
        l_zero_tax_code              VARCHAR2 (360);
        lv_company_reg_number        VARCHAR2 (60);
        lv_liquidation_number        VARCHAR2 (60);
        lv_share_capital             VARCHAR2 (60);
        lv_status_share              VARCHAR2 (60);
        le_address_province          VARCHAR2 (30) := NULL;
    BEGIN
        ln_ledger_id           := NULL;
        lv_period_start_date   := NULL;
        lv_period_end_date     := NULL;
        lv_begin_date          := NULL;
        lv_invoice_end_date    := NULL;

        FOR i IN cur_inv (pv_company_segment, pv_invoice_num, pv_from_date,
                          pv_to_date)
        LOOP
            ln_hdr_err_count   := 0;

            get_constant_values (i.company, lv_company_reg_number, lv_liquidation_number
                                 , lv_share_capital, lv_status_share);

            IF i.legal_entity_address_province IS NULL
            THEN
                BEGIN
                    SELECT hl.region_1
                      INTO le_address_province
                      FROM xle_registrations reg, xle_entity_profiles xep, hr_locations hl,
                           hr_operating_units hou
                     WHERE     xep.transacting_entity_flag = 'Y'
                           AND xep.legal_entity_id = reg.source_id
                           AND reg.source_table = 'XLE_ENTITY_PROFILES'
                           AND reg.identifying_flag = 'Y'
                           AND reg.location_id = hl.location_id
                           AND xep.legal_entity_id =
                               hou.default_legal_context_id
                           AND xep.legal_entity_identifier = i.company;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        le_address_province   := NULL;
                END;
            END IF;

            IF i.vat_rate = 0
            THEN
                BEGIN
                    SELECT LISTAGG (SUBSTR (description, 1, (INSTR (description, ':') - 1)), ', ') WITHIN GROUP (ORDER BY description)
                      INTO lv_tax_exempt_code
                      FROM fnd_lookup_values
                     WHERE     lookup_type = 'XXD_ARIC_VT_TAX_CODE_MAPPING'
                           AND enabled_flag = 'Y'
                           AND SYSDATE BETWEEN NVL (start_date_Active,
                                                    SYSDATE)
                                           AND NVL (end_date_active,
                                                    SYSDATE + 1)
                           AND language = 'US'
                           AND lookup_code = i.tax_code;


                    SELECT LISTAGG (SUBSTR (description, INSTR (description, ':') + 1), ', ') WITHIN GROUP (ORDER BY description)
                      INTO lv_tax_exempt_desc
                      FROM fnd_lookup_values
                     WHERE     lookup_type = 'XXD_ARIC_VT_TAX_CODE_MAPPING'
                           AND language = 'US'
                           AND enabled_flag = 'Y'
                           AND SYSDATE BETWEEN NVL (start_date_Active,
                                                    SYSDATE)
                                           AND NVL (end_date_active,
                                                    SYSDATE + 1)
                           AND lookup_code = i.tax_code;
                -- fnd_file.put_line (fnd_file.log, ' ld_tax_codeis : ' ||  ld_tax_code );

                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                            ' Exception ld_tax_codeis : ' || ld_tax_code);
                        lv_tax_exempt_code   := NULL;
                END;
            END IF;

            IF i.tax_line_cnt = 0
            THEN
                BEGIN
                    SELECT LISTAGG (SUBSTR (description, 1, (INSTR (description, ':') - 1)), ', ') WITHIN GROUP (ORDER BY description)
                      INTO lv_tax_exempt_code
                      FROM fnd_lookup_values
                     WHERE     lookup_type = 'XXD_ARIC_VT_TAX_CODE_MAPPING'
                           AND enabled_flag = 'Y'
                           AND SYSDATE BETWEEN NVL (start_date_Active,
                                                    SYSDATE)
                                           AND NVL (end_date_active,
                                                    SYSDATE + 1)
                           AND language = 'US'
                           AND lookup_code = 'NULL';


                    SELECT LISTAGG (SUBSTR (description, INSTR (description, ':') + 1), ', ') WITHIN GROUP (ORDER BY description)
                      INTO lv_tax_exempt_desc
                      FROM fnd_lookup_values
                     WHERE     lookup_type = 'XXD_ARIC_VT_TAX_CODE_MAPPING'
                           AND language = 'US'
                           AND enabled_flag = 'Y'
                           AND SYSDATE BETWEEN NVL (start_date_Active,
                                                    SYSDATE)
                                           AND NVL (end_date_active,
                                                    SYSDATE + 1)
                           AND lookup_code = 'NULL';
                -- fnd_file.put_line (fnd_file.log, ' ld_tax_codeis : ' ||  ld_tax_code );

                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                            ' Exception ld_tax_codeis : ' || ld_tax_code);
                        lv_tax_exempt_code   := NULL;
                END;
            END IF;


            -- validation starts

            IF i.invoice_number IS NULL
            THEN
                add_error_message (i.invoice_id,
                                   i.invoice_number,
                                   i.invoice_date,
                                   'INVALID_INVOICE_NUM',
                                   'The Invoice Number is Null');
                ln_hdr_err_count   := 1;
                lv_conc_error      :=
                    lv_conc_error || ',' || 'INVALID_INVOICE_NUM';
            END IF;

            IF i.invoice_date IS NULL
            THEN
                add_error_message (
                    i.invoice_id,
                    i.invoice_number,
                    i.invoice_date,
                    'INVALID_INVOICE_DATE',
                    'The Invoice Number does not have invoice date ');
                ln_hdr_err_count   := 1;
                lv_conc_error      :=
                    lv_conc_error || ',' || 'INVALID_INVOICE_DATE';
            END IF;

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

            IF i.LEGAL_ENTITY_NAME IS NULL
            THEN
                add_error_message (
                    i.invoice_id,
                    i.invoice_number,
                    i.invoice_date,
                    'LEGAL_ENTITY_NAME_NULL',
                    'Legal Entity Information is not available ');
                ln_hdr_err_count   := 1;
                lv_conc_error      :=
                    lv_conc_error || ',' || 'LEGAL_ENTITY_NAME_NULL';
            END IF;

            IF i.LEGAL_ENTITY_ADDRESS_STREET IS NULL
            THEN
                add_error_message (
                    i.invoice_id,
                    i.invoice_number,
                    i.invoice_date,
                    'LEGAL_ENTITY_ADDRESS_STREET_NULL',
                    'Legal Entity Address Street is not available ');
                ln_hdr_err_count   := 1;
                lv_conc_error      :=
                       lv_conc_error
                    || ','
                    || 'LEGAL_ENTITY_ADDRESS_STREET_NULL';
            END IF;

            IF i.LEGAL_ENTITY_ADDRESS_POSTAL_CODE IS NULL
            THEN
                add_error_message (i.invoice_id,
                                   i.invoice_number,
                                   i.invoice_date,
                                   'LEGAL_ENTITY_POSTAL_CODE_NULL',
                                   'Legal Entity does not have Postal Code ');
                ln_hdr_err_count   := 1;
                lv_conc_error      :=
                    lv_conc_error || ',' || 'LEGAL_ENTITY_POSTAL_CODE_NULL';
            END IF;

            IF i.LEGAL_ENTITY_ADDRESS_CITY IS NULL
            THEN
                add_error_message (
                    i.invoice_id,
                    i.invoice_number,
                    i.invoice_date,
                    'LEGAL_ENTITY_CITY_NULL',
                    'Legal Entity does not have Address City ');
                ln_hdr_err_count   := 1;
                lv_conc_error      :=
                    lv_conc_error || ',' || 'LEGAL_ENTITY_CITY_NULL';
            END IF;


            IF NVL (i.LEGAL_ENTITY_ADDRESS_PROVINCE, le_address_province)
                   IS NULL
            THEN
                add_error_message (i.invoice_id,
                                   i.invoice_number,
                                   i.invoice_date,
                                   'PROVINCE_REG_OFFICE_NULL',
                                   'Legal Entity does not have province');
                ln_hdr_err_count   := 1;
                lv_conc_error      :=
                    lv_conc_error || ',' || 'PROVINCE_REG_OFFICE_NULL';
            END IF;

            IF i.LEGAL_ENTITY_COUNTRY_CODE IS NULL
            THEN
                add_error_message (i.invoice_id,
                                   i.invoice_number,
                                   i.invoice_date,
                                   'LE_COUNTRY_CODE_NULL',
                                   'Legal Entity does not have Country Code');
                ln_hdr_err_count   := 1;
                lv_conc_error      :=
                    lv_conc_error || ',' || 'LE_COUNTRY_CODE_NULL';
            END IF;

            IF i.buyer_name IS NULL
            THEN
                add_error_message (i.invoice_id,
                                   i.invoice_number,
                                   i.invoice_date,
                                   'BUYER_NAME_NULL',
                                   'Buyer Name is not available ');
                ln_hdr_err_count   := 1;
                lv_conc_error      :=
                    lv_conc_error || ',' || 'BUYER_NAME_NULL';
            END IF;

            IF i.buyer_address_street IS NULL
            THEN
                add_error_message (i.invoice_id,
                                   i.invoice_number,
                                   i.invoice_date,
                                   'BUYER_ADDRESS_STREET_NULL',
                                   'Buyer Address Street is not available ');
                ln_hdr_err_count   := 1;
                lv_conc_error      :=
                    lv_conc_error || ',' || 'BUYER_ADDRESS_STREET_NULL';
            END IF;

            IF i.buyer_address_postal_code IS NULL
            THEN
                add_error_message (i.invoice_id,
                                   i.invoice_number,
                                   i.invoice_date,
                                   'BUYER_POSTCODE_NULL',
                                   'Buyer does not have Postal Code ');
                ln_hdr_err_count   := 1;
                lv_conc_error      :=
                    lv_conc_error || ',' || 'BUYER_POSTCODE_NULL';
            END IF;

            IF i.buyer_address_city IS NULL
            THEN
                add_error_message (i.invoice_id,
                                   i.invoice_number,
                                   i.invoice_date,
                                   'BUYER_CITY_NULL',
                                   'Buyer does not have Address City ');
                ln_hdr_err_count   := 1;
                lv_conc_error      :=
                    lv_conc_error || ',' || 'BUYER_CITY_NULL';
            END IF;

            IF i.buyer_address_country_code IS NULL
            THEN
                add_error_message (i.invoice_id,
                                   i.invoice_number,
                                   i.invoice_date,
                                   'BUYER_COUNTRY_NULL',
                                   'Buyer does not have Country Code');
                ln_hdr_err_count   := 1;
                lv_conc_error      :=
                    lv_conc_error || ',' || 'BUYER_COUNTRY_NULL';
            END IF;

            IF i.h_total_tax_amount IS NULL
            THEN
                add_error_message (i.invoice_id,
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
                add_error_message (i.invoice_id,
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
                    lv_conc_error || ',' || 'INVALID_NET_AMT_INCL_DISCOUNTS';
            END IF;

            -- correct it
            IF (i.H_TOTAL_NET_AMOUNT + i.h_total_tax_amount) IS NULL
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

            IF i.vat_amount IS NULL
            THEN
                add_error_message (i.invoice_id,
                                   i.invoice_number,
                                   i.invoice_date,
                                   'INVALID_VAT_AMOUNT',
                                   'The invoice does not have VAT amount');
                ln_hdr_err_count   := 1;
                lv_conc_error      :=
                    lv_conc_error || ',' || 'INVALID_VAT_AMOUNT';
            END IF;

            IF i.vat_net_amount IS NULL
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
                add_error_message (i.invoice_id,
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
                lv_conc_error      := lv_conc_error || ',' || 'INVALID_UOM';
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

            IF i.l_tax_rate IS NULL
            THEN
                add_error_message (
                    i.invoice_id,
                    i.invoice_number,
                    i.invoice_date,
                    'INVALID_L_VAT_RATE',
                    'The invoice line does not have VAT Rate information');
                ln_hdr_err_count   := 1;
                lv_conc_error      :=
                    lv_conc_error || ',' || 'INVALID_L_VAT_RATE';
            END IF;

            IF i.invoice_description IS NULL
            THEN
                add_error_message (
                    i.invoice_id,
                    i.invoice_number,
                    i.invoice_date,
                    'INVALID_LINE_DESCRIPTION',
                    'The invoice line does not have description information');
                ln_hdr_err_count   := 1;
                lv_conc_error      :=
                    lv_conc_error || ',' || 'INVALID_LINE_DESCRIPTION';
            END IF;



            BEGIN
                INSERT INTO XXDO.XXD_AR_IC_INV_STG (INVOICE_ID, INVOICE_NUMBER, INVOICE_DATE, PAYMENT_DUE_DATE, PAYMENT_TERM, INVOICE_CURRENCY_CODE, DOCUMENT_TYPE, DUTY_STAMP, ORG_ID, SET_OF_BOOKS_ID, COMPANY, ROUTING_CODE, INVOICE_DOC_REFERENCE, INV_DOC_REF_DESC, LEGAL_ENTITY_NAME, LE_VAT_NUMBER, LEGAL_ENTITY_ADDRESS_STREET, LEGAL_ENTITY_ADDRESS_POSTAL_CODE, LEGAL_ENTITY_ADDRESS_CITY, LEGAL_ENTITY_ADDRESS_PROVINCE, LEGAL_ENTITY_COUNTRY, LEGAL_ENTITY_COUNTRY_CODE, LE_REGISTRIATION_NUMBER, PROVINCE_REG_OFFICE, COMPANY_REG_NUMBER, SHARE_CAPITAL, STATUS_SHAREHOLDERS, LIQUIDATION_STATUS, BUYER_NAME, BUYER_VAT_NUMBER, BUYER_ADDRESS_STREET, BUYER_ADDRESS_POSTAL_CODE, BUYER_ADDRESS_CITY, BUYER_ADDRESS_PROVINCE, BUYER_ADDRESS_COUNTRY, BUYER_ADDRESS_COUNTRY_CODE, BUYER_BUSINESS_REGISTRATION_NUMBER, H_TOTAL_TAX_AMOUNT, H_TOTAL_NET_AMOUNT, H_TOTAL_NET_AMOUNT_INCLUDING_DISCOUNT_CHARGES, H_INVOICE_TOTAL, VAT_NET_AMOUNT, VAT_RATE, VAT_AMOUNT, TAX_CODE, TAX_EXEMPTION_DESCRIPTION, INVOICE_DESCRIPTION, UNIT_OF_MEASURE_CODE, QUANTITY_INVOICED, UNIT_PRICE, L_VAT_AMOUNT, L_TAX_RATE, L_TAX_EXEMPTION_CODE, L_NET_AMOUNT, H_DISCOUNT_AMOUNT, H_DISCOUNT_DESCRIPTION, H_DISCOUNT_TAX_RATE, H_CHARGE_AMOUNT, H_CHARGE_DESCRIPTION, H_CHARGE_TAX_RATE, L_DISCOUNT_AMOUNT, L_DISCOUNT_DESCRIPTION, L_CHARGE_AMOUNT, L_CHARGE_DESCRIPTION, L_DESCRIPTION_GOODS, EXCHANGE_RATE, EXCHANGE_DATE, ORIGINAL_CURRENCY_CODE, CREATED_BY, CREATION_DATE, LAST_UPDATED_BY, LAST_UPDATE_DATE, LAST_UPDATE_LOGIN, CONC_REQUEST_ID, PROCESS_FLAG, REPROCESS_FLAG, EXTRACT_FLAG, EXTRACT_DATE
                                                    , ERROR_CODE)
                     VALUES (i.INVOICE_ID, remove_junk (i.INVOICE_NUMBER), i.INVOICE_DATE, i.PAYMENT_DUE_DATE, remove_junk (i.PAYMENT_TERM), 'EUR', i.document_type, i.duty_stamp, NULL --i.ORG_ID
                                                                                                                                                                                       , NULL --i.SET_OF_BOOKS_ID
                                                                                                                                                                                             , i.company --i.COMPANY
                                                                                                                                                                                                        , i.routing_code, remove_junk (i.invoice_doc_reference), i.inv_doc_ref_desc, remove_junk (i.legal_entity_name), remove_junk (i.le_vat_number), remove_junk (i.legal_entity_address_street), i.legal_entity_address_postal_code, remove_junk (i.legal_entity_address_city), NVL (i.legal_entity_address_province, le_address_province), i.legal_entity_country, i.legal_entity_country_code, i.le_registriation_number, NVL (i.legal_entity_address_province, le_address_province), lv_company_reg_number, lv_share_capital, lv_status_share, lv_liquidation_number, remove_junk (i.buyer_name), remove_junk (i.buyer_vat_registration_number), remove_junk (i.buyer_address_street), i.buyer_address_postal_code, remove_junk (i.buyer_address_city), i.buyer_address_province, i.buyer_address_country, remove_junk (i.buyer_address_country_code), i.buyer_business_registration_number, DECODE (i.tax_line_cnt, 0, 0, DECODE (i.invoice_currency_code, 'EUR', i.h_total_tax_amount, ROUND ((i.h_total_tax_amount * i.exchange_rate), 2))) --h_total_tax_amount
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    , DECODE (i.invoice_currency_code, 'EUR', i.h_total_net_amount, TRUNC ((i.h_total_net_amount * i.exchange_rate), 2)) -- h_total_net_amount
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        , DECODE (i.invoice_currency_code, 'EUR', i.h_total_net_amount_including_discount_charges, TRUNC ((i.h_total_net_amount_including_discount_charges * i.exchange_rate), 2)) --h_total_net_amount_including_discount_charges
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  , DECODE (i.invoice_currency_code, 'EUR', ROUND ((i.H_TOTAL_NET_AMOUNT + i.h_total_tax_amount), 2), TRUNC ((ROUND ((i.H_TOTAL_NET_AMOUNT + i.h_total_tax_amount), 2) * i.exchange_rate), 2)) -- H_INVOICE_TOTAL
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              , DECODE (i.invoice_currency_code, 'EUR', TO_NUMBER (i.vat_net_amount), ROUND ((TO_NUMBER (i.vat_net_amount) * i.exchange_rate), 2)) -- vat_net_amount
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  , DECODE (i.tax_line_cnt, 0, 0, TO_NUMBER (i.vat_rate)) --VAT_RATE
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         , DECODE (i.tax_line_cnt, 0, 0, DECODE (i.invoice_currency_code, 'EUR', DECODE (i.invoice_class, 'CM', (-1 * TO_NUMBER (i.vat_amount)), TO_NUMBER (i.vat_amount)), ROUND ((DECODE (i.invoice_class, 'CM', (-1 * TO_NUMBER (i.vat_amount)), TO_NUMBER (i.vat_amount)) * i.exchange_rate), 2))) -- vat_amount
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      , DECODE (i.tax_line_cnt, 0, lv_tax_exempt_code, DECODE (i.vat_rate, 0, lv_tax_exempt_code, NULL)) --TAX_CODE
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        , DECODE (i.tax_line_cnt, 0, lv_tax_exempt_desc, DECODE (i.vat_rate, 0, lv_tax_exempt_desc, NULL)), remove_junk (i.invoice_description), i.Unit_Of_Measure_Code, i.quantity_invoiced, DECODE (i.invoice_currency_code, 'EUR', i.unit_price, ROUND ((i.unit_price * i.exchange_rate), 2)) -- unit_price
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                , i.l_vat_amount, DECODE (i.tax_line_cnt, 0, 0, DECODE (i.tax_code, 'SUPPRESS', 0, i.vat_rate)) --L_TAX_RATE
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               , DECODE (i.vat_rate, 0, lv_tax_exempt_code, NULL), DECODE (i.invoice_currency_code, 'EUR', i.l_net_amount, ROUND ((i.l_net_amount * i.exchange_rate), 2)) -- net_amount
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         , i.h_discount_amount, i.h_discount_description, i.h_discount_tax_rate, i.h_charge_amount, i.h_charge_description, i.h_charge_tax_rate, i.l_discount_amount, i.l_discount_description, i.l_charge_amount, i.l_charge_description, i.l_description_goods, DECODE (i.invoice_currency_code, 'EUR', NULL, i.exchange_rate), DECODE (i.invoice_currency_code, 'EUR', NULL, i.exchange_date), i.invoice_currency_code, gn_user_id, SYSDATE, gn_user_id, SYSDATE, gn_login_id, gn_request_id, 'N', pv_reprocess_flag, NULL, NULL
                             , NULL);
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           i.invoice_number
                        || 'Failed to insert the data into custom table:'
                        || SQLERRM);
            END;

            BEGIN
                IF ln_hdr_err_count = 1
                THEN
                    UPDATE xxdo.XXD_AR_IC_INV_STG
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
        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'failed at insert_ar_eligible_recs exception');
            fnd_file.put_line (
                fnd_file.LOG,
                'Failed to insert the data into custom table:' || SQLERRM);
    END insert_ar_eligible_recs;

    PROCEDURE insert_ap_eligible_recs (pv_company_segment IN VARCHAR2, pv_reprocess_flag IN VARCHAR2, pv_invoice_num IN NUMBER, pv_from_date IN VARCHAR2, pv_to_date IN VARCHAR2, x_ret_code OUT VARCHAR2
                                       , x_ret_message OUT VARCHAR2)
    IS
        CURSOR cur_inv (p_company_segment IN VARCHAR2, pv_invoice_num IN NUMBER, pv_from_date IN VARCHAR2
                        , pv_to_date IN VARCHAR2)
        IS
            (SELECT xih.invoice_header_id
                        invoice_id,
                    xih.invoice_number,
                    TO_CHAR (xih.invoice_date, 'DD-MON-YYYY')
                        invoice_date,
                    TO_CHAR (xih.invoice_date, 'DD-MON-YYYY')
                        payment_due_date,
                    apt.name
                        payment_term,
                    xih.attribute3
                        company,
                    xih.invoice_currency
                        invoice_currency_code,
                    xil.attribute_id,
                    xil.transaction_ref,
                    xih.invoice_class,
                    NULL
                        document_type,
                    NULL
                        invoice_doc_reference,
                    NULL
                        inv_doc_ref_desc,
                    seller.bill_to_name
                        LEGAL_ENTITY_NAME,
                    seller.bill_to_address_line_1
                        LEGAL_ENTITY_ADDRESS_STREET,
                    seller.bill_to_postal_code
                        LEGAL_ENTITY_ADDRESS_POSTAL_CODE,
                    seller.bill_to_town_or_city
                        LEGAL_ENTITY_ADDRESS_CITY,
                    seller.bill_to_region
                        LEGAL_ENTITY_ADDRESS_PROVINCE,
                    seller.bill_to_country
                        LEGAL_ENTITY_COUNTRY,
                    seller.bill_to_country_code
                        LEGAL_ENTITY_COUNTRY_CODE,
                    xih.attribute5
                        le_vat_number,
                    xih.attribute5
                        le_registriation_number,
                    NULL
                        province_reg_office,
                    NULL
                        company_reg_number,
                    NULL
                        share_capital,
                    NULL
                        status_shareholders,
                    NULL
                        liquidation_status,
                    cust.bill_to_name
                        buyer_name,
                    cust.bill_to_address_line_1
                        buyer_address_street,
                    cust.bill_to_postal_code
                        buyer_address_postal_code,
                    cust.bill_to_town_or_city
                        buyer_address_city,
                    cust.bill_to_region
                        buyer_address_province,
                    cust.bill_to_country
                        buyer_address_country,
                    cust.bill_to_country_code
                        buyer_address_country_code,
                    xih.attribute4
                        buyer_vat_registration_number,
                    xih.attribute4
                        buyer_business_registration_number,
                    NULL
                        h_total_tax_amount,
                    get_routing_code (xih.attribute3)
                        routing_code,
                    DECODE (
                        xih.invoice_class,
                        'CM', ABS (
                                  get_ap_h_tot_net_amount (
                                      xih.attribute3,
                                      xih.invoice_header_id)),
                        get_ap_h_tot_net_amount (xih.attribute3,
                                                 xih.invoice_header_id))
                        h_total_net_amount,
                    DECODE (
                        xih.invoice_class,
                        'CM', ABS (
                                  get_ap_h_tot_net_amount (
                                      xih.attribute3,
                                      xih.invoice_header_id)),
                        get_ap_h_tot_net_amount (xih.attribute3,
                                                 xih.invoice_header_id))
                        h_total_net_amount_including_discount_charges,
                    NULL
                        h_invoice_total,
                    NULL
                        vat_net_amount,
                    NULL
                        vat_rate,
                    NULL
                        vat_amount,
                    NULL
                        tax_exemption_description,
                    NVL (remove_junk (xil.attribute2),
                         'AR Intercompany Invoice')
                        invoice_description,
                    'EA'
                        unit_of_measure_code,
                    xil.quantity
                        quantity_invoiced,
                    DECODE (xih.invoice_class,
                            'CM', ABS (xil.ic_unit_price),
                            xil.ic_unit_price)
                        unit_price,
                    xil.ic_tax_amount
                        l_vat_amount,
                    NULL
                        l_tax_rate,
                    NULL
                        tax_code,
                    NULL
                        l_tax_exemption_code,
                    DECODE (xih.invoice_class,
                            'CM', ABS (quantity * ic_price),
                            (quantity * ic_price))
                        l_net_amount,
                    NULL
                        h_discount_amount,
                    NULL
                        h_discount_description,
                    NULL
                        h_discount_tax_rate,
                    NULL
                        l_discount_amount,
                    NULL
                        l_discount_description,
                    NULL
                        l_charge_amount,
                    NULL
                        l_charge_description,
                    NULL
                        l_description_goods,
                    NULL
                        tax_classification,
                    NULL
                        h_charge_amount,
                    NULL
                        h_charge_description,
                    NULL
                        h_charge_tax_rate,
                    DECODE (
                        xih.invoice_currency,
                        'EUR', NULL,
                        (SELECT accounted_exch_rate
                           FROM xxcp_process_history ph
                          WHERE     ph.attribute_id = xil.attribute_id
                                AND ph.status = 'GLI'
                                AND ph.accounted_exch_rate IS NOT NULL
                                AND ROWNUM = 1))
                        exchange_rate,
                    DECODE (
                        xih.invoice_currency,
                        'EUR', NULL,
                        (SELECT TO_CHAR (accounting_date, 'DD-MON-YYYY')
                           FROM xxcp_process_history ph
                          WHERE     ph.attribute_id = xil.attribute_id
                                AND ph.status = 'GLI'
                                AND ph.accounting_date IS NOT NULL
                                AND ROWNUM = 1))
                        exchange_date,
                    (SELECT xph.category
                       FROM xxcp_process_history xph
                      WHERE     xph.attribute_id = xil.attribute_id
                            AND xph.category IS NOT NULL
                            AND ROWNUM = 1)
                        ic_category,
                    xih.invoice_currency
                        original_currency_code,
                    xil.attribute10
                        line_type
               FROM apps.xxcp_ic_inv_header xih, apps.xxcp_ic_inv_lines xil, xxcp_address_details seller,
                    xxcp_address_details cust, apps.xxcp_process_history ph, apps.ap_terms apt
              WHERE     1 = 1
                    AND xih.attribute3 = pv_company_segment            --'580'
                    AND xih.invoice_class = 'CM'
                    AND xih.invoice_header_id = xil.invoice_header_id
                    AND cust.address_id = xih.invoice_address_id
                    AND seller.address_id = xih.customer_address_id
                    AND xil.attribute10 IN ('O', 'S')
                    AND xih.payment_term_id = apt.term_id(+)
                    AND xil.attribute_id = ph.attribute_id
                    AND xil.process_history_id = ph.process_history_id
                    AND NOT EXISTS
                            (SELECT 1
                               FROM xxcp_account_rules xar
                              WHERE     NVL (xar.rule_category_1, 'X') =
                                        'REVERSE'
                                    AND xar.rule_id = ph.rule_id)
                    AND EXISTS
                            (SELECT 1
                               FROM xxcp_ic_inv_header hdr, xxcp_ic_inv_lines line, xxcp_process_history xph
                              WHERE     hdr.attribute3 = xih.attribute3
                                    AND hdr.invoice_class = 'CM'
                                    AND hdr.invoice_number NOT LIKE
                                            'INTERIM%'
                                    AND hdr.invoice_header_id =
                                        line.invoice_header_id
                                    AND hdr.invoice_header_id =
                                        xih.invoice_header_id
                                    AND line.invoice_line_id =
                                        xil.invoice_line_id
                                    AND line.ic_line_amount < 0
                                    AND line.attribute_id = xph.attribute_id
                                    AND xph.status = 'GLI'
                                    AND xph.category <> 'VT Inventory')
                    AND xih.invoice_header_id =
                        NVL (pv_invoice_num, xih.invoice_header_id)
                    AND NVL (xih.extract_flag, 'N') =
                        DECODE (pv_reprocess_flag, 'Y', 'Y', 'N')
                    AND xih.invoice_date BETWEEN NVL (pv_from_date,
                                                      xih.invoice_date)
                                             AND pv_to_date);

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
        lv_tax_code                  VARCHAR2 (100);
        lv_tax_codrate               VARCHAR2 (100);
        lv_tax_rate                  NUMBER;
        ln_cnt_attr3                 NUMBER;
        ln_cnt_attr4                 NUMBER;
        lv_final_tax_code            VARCHAR2 (100) := NULL;
        lv_final_tax_rate            NUMBER := 0;
        lv_document_type             VARCHAR2 (60);
        l_h_tot_amount               NUMBER;
        l_vat_net_amount             NUMBER;
        l_vat_amount                 NUMBER;
        lv_tax_exempt_desc           VARCHAR2 (250) := NULL;
        lv_tax_exempt_code           VARCHAR2 (250) := NULL;
        lv_tax_classification        VARCHAR2 (100) := NULL;
        ld_tax_code                  VARCHAR2 (250);
        l_tax_line_cnt               NUMBER;
        l_zero_tax_code              VARCHAR2 (360);
        l_invoice_id                 NUMBER;
        l_orginal_inv_num            VARCHAR2 (60);
        l_org_id                     NUMBER;
        l_original_invoice           VARCHAR2 (60) := NULL;
        lv_company_reg_number        VARCHAR2 (60);
        lv_liquidation_number        VARCHAR2 (60);
        lv_share_capital             VARCHAR2 (60);
        lv_status_share              VARCHAR2 (60);
        le_address_province          VARCHAR2 (30) := NULL;
    BEGIN
        ln_ledger_id           := NULL;
        lv_period_start_date   := NULL;
        lv_period_end_date     := NULL;
        lv_begin_date          := NULL;
        lv_invoice_end_date    := NULL;

        FOR i IN cur_inv (pv_company_segment, pv_invoice_num, pv_from_date,
                          pv_to_date)
        LOOP
            ln_hdr_err_count   := 0;

            get_constant_values (i.company, lv_company_reg_number, lv_liquidation_number
                                 , lv_share_capital, lv_status_share);

            IF i.legal_entity_address_province IS NULL
            THEN
                BEGIN
                    SELECT hl.region_1
                      INTO le_address_province
                      FROM xle_registrations reg, xle_entity_profiles xep, hr_locations hl,
                           hr_operating_units hou
                     WHERE     xep.transacting_entity_flag = 'Y'
                           AND xep.legal_entity_id = reg.source_id
                           AND reg.source_table = 'XLE_ENTITY_PROFILES'
                           AND reg.identifying_flag = 'Y'
                           AND reg.location_id = hl.location_id
                           AND xep.legal_entity_id =
                               hou.default_legal_context_id
                           AND xep.legal_entity_identifier = i.company;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        le_address_province   := NULL;
                END;
            END IF;

            IF i.ic_category = 'VT Cash Management'
            THEN
                lv_final_tax_rate   := 0;
                lv_final_tax_code   := NULL;
            ELSIF i.ic_category = 'VT Payables'
            THEN
                BEGIN
                    SELECT attribute3, (TO_NUMBER (attribute4) * 100)
                      INTO lv_final_tax_code, lv_final_tax_rate
                      FROM apps.xxcp_process_history ph
                     WHERE     ph.attribute_id = i.attribute_id
                           AND ph.segment1 = i.company
                           AND ph.status = 'GLI'
                           AND ph.segment6 IN ('11901', '11902');
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        BEGIN
                            SELECT attribute3, (TO_NUMBER (attribute4) * 100)
                              INTO lv_final_tax_code, lv_final_tax_rate
                              FROM apps.xxcp_process_history ph
                             WHERE     ph.attribute_id = i.attribute_id
                                   AND ph.status = 'GLI'
                                   AND ph.attribute3 IS NOT NULL
                                   AND ROWNUM = 1;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_final_tax_code   := NULL;
                                lv_final_tax_rate   := 0;
                        END;
                END;
            ELSIF i.ic_category = 'VT Manual'
            THEN
                BEGIN
                    SELECT attribute4, (TO_NUMBER (attribute5) * 100)
                      INTO lv_final_tax_code, lv_final_tax_rate
                      FROM apps.xxcp_process_history ph
                     WHERE     ph.attribute_id = i.attribute_id
                           AND ph.segment1 = i.company
                           AND ph.status = 'GLI'
                           AND ph.segment6 IN ('11901', '11902');
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        BEGIN
                            SELECT attribute4, (TO_NUMBER (attribute5) * 100)
                              INTO lv_final_tax_code, lv_final_tax_rate
                              FROM apps.xxcp_process_history ph
                             WHERE     ph.attribute_id = i.attribute_id
                                   AND ph.status = 'GLI'
                                   AND ph.attribute4 IS NOT NULL
                                   AND ROWNUM = 1;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_final_tax_code   := NULL;
                                lv_final_tax_rate   := 0;
                        END;
                END;
            ELSIF i.ic_category = 'VT Inventory'
            THEN
                BEGIN
                    SELECT attribute4, (TO_NUMBER (attribute5) * 100)
                      INTO lv_final_tax_code, lv_final_tax_rate
                      FROM apps.xxcp_process_history ph
                     WHERE     ph.attribute_id = i.attribute_id
                           AND ph.segment1 = i.company
                           AND ph.status = 'GLI'
                           AND ph.segment6 IN ('11901', '11902');
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        BEGIN
                            SELECT attribute4, (TO_NUMBER (attribute5) * 100)
                              INTO lv_final_tax_code, lv_final_tax_rate
                              FROM apps.xxcp_process_history ph
                             WHERE     ph.attribute_id = i.attribute_id
                                   AND ph.status = 'GLI'
                                   AND ph.attribute4 IS NOT NULL
                                   AND ROWNUM = 1;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_final_tax_code   := NULL;
                                lv_final_tax_rate   := 0;
                        END;
                END;
            ELSIF i.ic_category = 'VT Fixed Assets'
            THEN
                BEGIN
                    SELECT attribute3, (TO_NUMBER (attribute4) * 100)
                      INTO lv_final_tax_code, lv_final_tax_rate
                      FROM apps.xxcp_process_history ph
                     WHERE     ph.attribute_id = i.attribute_id
                           AND ph.segment1 = i.company
                           AND ph.status = 'GLI'
                           AND ph.segment6 IN ('11901', '11902');
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_final_tax_code   := NULL;
                        lv_final_tax_rate   := 0;
                END;
            ELSIF i.ic_category = 'VT projects'
            THEN
                BEGIN
                    SELECT attribute3, (TO_NUMBER (attribute4) * 100)
                      INTO lv_final_tax_code, lv_final_tax_rate
                      FROM apps.xxcp_process_history ph
                     WHERE     ph.attribute_id = i.attribute_id
                           AND ph.segment1 = i.company
                           AND ph.status = 'GLI'
                           AND ph.segment6 IN ('11901', '11902');
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_final_tax_code   := NULL;
                        lv_final_tax_rate   := 0;
                END;
            ELSE
                BEGIN
                    SELECT ph.attribute3, ph.attribute4, ph.attribute5,
                           REGEXP_COUNT (ph.attribute3, '[A-Za-z]') cnt_attr3, REGEXP_COUNT (ph.attribute4, '[A-Za-z]') cnt_attr4
                      INTO lv_tax_code, lv_tax_codrate, lv_tax_rate, ln_cnt_attr3,
                                      ln_cnt_attr4
                      FROM apps.xxcp_process_history ph
                     WHERE     ph.attribute_id = i.attribute_id
                           AND ph.segment1 = i.company
                           AND ph.status = 'GLI'
                           AND ph.segment6 IN ('11901', '11902');
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_cnt_attr3   := 0;
                        ln_cnt_attr4   := 0;
                END;

                IF ln_cnt_attr3 >= 1
                THEN
                    BEGIN
                        SELECT attribute3, (TO_NUMBER (attribute4) * 100)
                          INTO lv_final_tax_code, lv_final_tax_rate
                          FROM apps.xxcp_process_history ph
                         WHERE     ph.attribute_id = i.attribute_id
                               AND ph.segment1 = i.company
                               AND ph.status = 'GLI'
                               AND ph.segment6 IN ('11901', '11902');
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_final_tax_code   := NULL;
                            lv_final_tax_rate   := 0;
                    END;
                END IF;

                IF ln_cnt_attr4 >= 1
                THEN
                    BEGIN
                        SELECT attribute4, (TO_NUMBER (attribute5) * 100)
                          INTO lv_final_tax_code, lv_final_tax_rate
                          FROM apps.xxcp_process_history ph
                         WHERE     ph.attribute_id = i.attribute_id
                               AND ph.segment1 = i.company
                               AND ph.status = 'GLI'
                               AND ph.segment6 IN ('11901', '11902');
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_final_tax_code   := NULL;
                            lv_final_tax_rate   := 0;
                    END;
                END IF;
            END IF;

            IF lv_final_tax_code IS NOT NULL
            THEN
                lv_document_type   := get_document_type (lv_final_tax_code);

                -- h total tax amount
                BEGIN
                    SELECT DECODE (lv_final_tax_code, 'SUPPRESS', 0, get_ap_h_tot_tax_amount (i.company, i.invoice_id, i.attribute_id))
                      INTO l_h_tot_amount
                      FROM DUAL;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_h_tot_amount   := 0;
                END;

                -- vat net amount
                BEGIN
                    SELECT DECODE (lv_final_tax_code,
                                   'SUPPRESS', 0,
                                   get_ap_vat_net_amount (i.company, i.invoice_id, lv_final_tax_rate
                                                          , i.ic_category))
                      INTO l_vat_net_amount
                      FROM DUAL;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_vat_net_amount   := 0;
                END;

                -- vat amount

                BEGIN
                    SELECT DECODE (lv_final_tax_code,              -- tax code
                                                       'SUPPRESS', 0,  'ITVAT_NOT_LIABLE', 0,  get_ap_vat_amount (i.company, i.invoice_id, i.attribute_id))
                      INTO l_vat_amount
                      FROM DUAL;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_vat_amount   := 0;
                END;


                -- Tax Classification

                BEGIN
                    SELECT attribute2
                      INTO lv_tax_classification
                      FROM xxcp_cust_data
                     WHERE     1 = 1
                           AND category_name = 'ONESOURCE TAX CODES MAPPING'
                           AND attribute1 = lv_final_tax_code;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_tax_classification   := NULL;
                END;

                -- tax code

                BEGIN
                    SELECT LISTAGG (SUBSTR (description, 1, (INSTR (description, ':') - 1)), ', ') WITHIN GROUP (ORDER BY description)
                      INTO ld_tax_code
                      FROM apps.fnd_lookup_values
                     WHERE     lookup_type = 'XXD_APIC_VT_TAX_CODE_MAPPING'
                           AND enabled_flag = 'Y'
                           AND SYSDATE BETWEEN NVL (start_date_active,
                                                    SYSDATE)
                                           AND NVL (end_date_active,
                                                    SYSDATE + 1)
                           AND language = 'US'
                           AND lookup_code = lv_final_tax_code;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ld_tax_code   := NULL;
                END;
            END IF;

            IF lv_final_tax_code IS NULL
            THEN
                lv_document_type        := get_document_type (lv_final_tax_code);
                l_h_tot_amount          := 0;
                lv_tax_classification   := NULL;

                -- vat net amount
                BEGIN
                    SELECT get_ap_vat_net_amount (i.company, i.invoice_id, lv_final_tax_rate
                                                  , i.ic_category)
                      INTO l_vat_net_amount
                      FROM DUAL;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_vat_net_amount   := 0;
                END;

                -- vat amount

                /*     BEGIN
                         SELECT
                             get_vat_amount(i.company, i.invoice_id, i.attribute_id)
                         INTO l_vat_amount
                         FROM
                             dual;

                     EXCEPTION
                         WHEN OTHERS THEN
                             l_vat_amount := 0;
                     END;*/

                l_vat_amount            := 0;

                -- tax code

                BEGIN
                    SELECT LISTAGG (SUBSTR (description, 1, (INSTR (description, ':') - 1)), ', ') WITHIN GROUP (ORDER BY description)
                      INTO ld_tax_code
                      FROM apps.fnd_lookup_values
                     WHERE     lookup_type = 'XXD_APIC_VT_TAX_CODE_MAPPING'
                           AND enabled_flag = 'Y'
                           AND SYSDATE BETWEEN NVL (start_date_active,
                                                    SYSDATE)
                                           AND NVL (end_date_active,
                                                    SYSDATE + 1)
                           AND language = 'US'
                           AND lookup_code = lv_final_tax_code;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ld_tax_code   := NULL;
                END;

                BEGIN
                    SELECT LISTAGG (SUBSTR (description, INSTR (description, ':') + 1), ', ') WITHIN GROUP (ORDER BY description)
                      INTO lv_tax_exempt_desc
                      FROM fnd_lookup_values
                     WHERE     lookup_type = 'XXD_ARIC_VT_TAX_CODE_MAPPING'
                           AND language = 'US'
                           AND enabled_flag = 'Y'
                           AND SYSDATE BETWEEN NVL (start_date_Active,
                                                    SYSDATE)
                                           AND NVL (end_date_active,
                                                    SYSDATE + 1)
                           AND lookup_code = lv_final_tax_code;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_tax_exempt_desc   := NULL;
                END;
            END IF;

            --

            -- validation starts

            IF i.invoice_number IS NULL
            THEN
                add_error_message (i.invoice_id,
                                   i.invoice_number,
                                   i.invoice_date,
                                   'INVALID_INVOICE_NUM',
                                   'The Invoice Number is Null');

                ln_hdr_err_count   := 1;
                lv_conc_error      :=
                    lv_conc_error || ',' || 'INVALID_INVOICE_NUM';
            END IF;

            IF i.invoice_date IS NULL
            THEN
                add_error_message (
                    i.invoice_id,
                    i.invoice_number,
                    i.invoice_date,
                    'INVALID_INVOICE_DATE',
                    'The Invoice Number does not have invoice date ');

                ln_hdr_err_count   := 1;
                lv_conc_error      :=
                    lv_conc_error || ',' || 'INVALID_INVOICE_DATE';
            END IF;

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

            IF lv_document_type IS NULL
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

            IF i.legal_entity_name IS NULL
            THEN
                add_error_message (i.invoice_id,
                                   i.invoice_number,
                                   i.invoice_date,
                                   'LEGAL_ENTITY_NAME_NULL',
                                   'Legal Entity Name is not available ');

                ln_hdr_err_count   := 1;
                lv_conc_error      :=
                    lv_conc_error || ',' || 'LEGAL_ENTITY_NAME_NULL';
            END IF;

            IF i.legal_entity_address_street IS NULL
            THEN
                add_error_message (
                    i.invoice_id,
                    i.invoice_number,
                    i.invoice_date,
                    'LEGAL_ENTITY_ADDRESS_STREET_NULL',
                    'Legal Entity Address Street is not available ');

                ln_hdr_err_count   := 1;
                lv_conc_error      :=
                       lv_conc_error
                    || ','
                    || 'LEGAL_ENTITY_ADDRESS_STREET_NULL';
            END IF;

            IF i.legal_entity_address_postal_code IS NULL
            THEN
                add_error_message (i.invoice_id,
                                   i.invoice_number,
                                   i.invoice_date,
                                   'LEGAL_ENTITY_POSTAL_CODE_NULL',
                                   'Legal Entity does not have Postal Code ');

                ln_hdr_err_count   := 1;
                lv_conc_error      :=
                    lv_conc_error || ',' || 'LEGAL_ENTITY_POSTAL_CODE_NULL';
            END IF;

            IF i.LEGAL_ENTITY_ADDRESS_CITY IS NULL
            THEN
                add_error_message (
                    i.invoice_id,
                    i.invoice_number,
                    i.invoice_date,
                    'LEGAL_ENTITY_CITY_NULL',
                    'Legal Entity does not have Address City ');

                ln_hdr_err_count   := 1;
                lv_conc_error      :=
                    lv_conc_error || ',' || 'LEGAL_ENTITY_CITY_NULL';
            END IF;

            IF i.LEGAL_ENTITY_COUNTRY_CODE IS NULL
            THEN
                add_error_message (i.invoice_id,
                                   i.invoice_number,
                                   i.invoice_date,
                                   'LE_COUNTRY_CODE_NULL',
                                   'Legal Entity does not have Country Code');

                ln_hdr_err_count   := 1;
                lv_conc_error      :=
                    lv_conc_error || ',' || 'LE_COUNTRY_CODE_NULL';
            END IF;

            IF i.buyer_name IS NULL
            THEN
                add_error_message (i.invoice_id,
                                   i.invoice_number,
                                   i.invoice_date,
                                   'BUYER_NAME_NULL',
                                   'Buyer Name is not available ');

                ln_hdr_err_count   := 1;
                lv_conc_error      :=
                    lv_conc_error || ',' || 'BUYER_NAME_NULL';
            END IF;

            IF i.buyer_address_street IS NULL
            THEN
                add_error_message (i.invoice_id,
                                   i.invoice_number,
                                   i.invoice_date,
                                   'BUYER_ADDRESS_STREET_NULL',
                                   'Buyer Address Street is not available ');

                ln_hdr_err_count   := 1;
                lv_conc_error      :=
                    lv_conc_error || ',' || 'BUYER_ADDRESS_STREET_NULL';
            END IF;

            IF i.buyer_address_postal_code IS NULL
            THEN
                add_error_message (i.invoice_id,
                                   i.invoice_number,
                                   i.invoice_date,
                                   'BUYER_POSTCODE_NULL',
                                   'Buyer does not have Postal Code ');

                ln_hdr_err_count   := 1;
                lv_conc_error      :=
                    lv_conc_error || ',' || 'BUYER_POSTCODE_NULL';
            END IF;

            IF i.buyer_address_city IS NULL
            THEN
                add_error_message (i.invoice_id,
                                   i.invoice_number,
                                   i.invoice_date,
                                   'BUYER_CITY_NULL',
                                   'Buyer does not have Address City ');

                ln_hdr_err_count   := 1;
                lv_conc_error      :=
                    lv_conc_error || ',' || 'BUYER_CITY_NULL';
            END IF;

            IF i.buyer_address_country_code IS NULL
            THEN
                add_error_message (i.invoice_id,
                                   i.invoice_number,
                                   i.invoice_date,
                                   'BUYER_COUNTRY_NULL',
                                   'Buyer does not have Country Code');

                ln_hdr_err_count   := 1;
                lv_conc_error      :=
                    lv_conc_error || ',' || 'BUYER_COUNTRY_NULL';
            END IF;

            IF l_h_tot_amount IS NULL
            THEN
                add_error_message (i.invoice_id,
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
                add_error_message (i.invoice_id,
                                   i.invoice_number,
                                   i.invoice_date,
                                   'INVALID_TOTAL_NET_AMOUNT',
                                   'Invalid Total NET amount of the invoice');

                ln_hdr_err_count   := 1;
                lv_conc_error      :=
                    lv_conc_error || ',' || 'INVALID_TOTAL_NET_AMOUNT';
            END IF;

            IF i.h_total_net_amount IS NULL
            THEN
                add_error_message (
                    i.invoice_id,
                    i.invoice_number,
                    i.invoice_date,
                    'INVALID_NET_AMT_INCL_DISCOUNTS',
                    'Invalid Total Invoice amount including discounts');

                ln_hdr_err_count   := 1;
                lv_conc_error      :=
                    lv_conc_error || ',' || 'INVALID_NET_AMT_INCL_DISCOUNTS';
            END IF;

            -- correct it

            IF (i.h_total_net_amount + l_h_tot_amount) IS NULL
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

            IF lv_final_tax_rate IS NULL
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
                add_error_message (i.invoice_id,
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
                add_error_message (i.invoice_id,
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
                lv_conc_error      := lv_conc_error || ',' || 'INVALID_UOM';
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

            IF lv_final_tax_rate IS NULL
            THEN
                add_error_message (
                    i.invoice_id,
                    i.invoice_number,
                    i.invoice_date,
                    'INVALID_L_VAT_RATE',
                    'The invoice line does not have VAT Rate information');

                ln_hdr_err_count   := 1;
                lv_conc_error      :=
                    lv_conc_error || ',' || 'INVALID_L_VAT_RATE';
            END IF;

            IF i.invoice_description IS NULL
            THEN
                add_error_message (
                    i.invoice_id,
                    i.invoice_number,
                    i.invoice_date,
                    'INVALID_LINE_DESCRIPTION',
                    'The invoice line does not have description information');

                ln_hdr_err_count   := 1;
                lv_conc_error      :=
                    lv_conc_error || ',' || 'INVALID_LINE_DESCRIPTION';
            END IF;

            BEGIN
                INSERT INTO xxdo.XXD_AR_IC_INV_STG (
                                invoice_id,
                                invoice_number,
                                invoice_date,
                                payment_due_date,
                                payment_term,
                                invoice_currency_code,
                                document_type,
                                org_id,
                                set_of_books_id,
                                company,
                                routing_code,
                                invoice_doc_reference,
                                inv_doc_ref_desc,
                                legal_entity_name,
                                le_vat_number,
                                legal_entity_address_street,
                                legal_entity_address_postal_code,
                                legal_entity_address_city,
                                legal_entity_address_province,
                                legal_entity_country,
                                legal_entity_country_code,
                                le_registriation_number,
                                province_reg_office,
                                company_reg_number,
                                share_capital,
                                status_shareholders,
                                liquidation_status,
                                buyer_name,
                                buyer_vat_number,
                                buyer_address_street,
                                buyer_address_postal_code,
                                buyer_address_city,
                                buyer_address_province,
                                buyer_address_country,
                                buyer_address_country_code,
                                buyer_business_registration_number,
                                h_total_tax_amount,
                                h_total_net_amount,
                                h_total_net_amount_including_discount_charges,
                                h_invoice_total,
                                vat_net_amount,
                                vat_rate,
                                vat_amount,
                                tax_code,
                                tax_exemption_description,
                                invoice_description,
                                unit_of_measure_code,
                                quantity_invoiced,
                                unit_price,
                                l_vat_amount,
                                l_tax_rate,
                                l_tax_exemption_code,
                                l_net_amount,
                                h_discount_amount,
                                h_discount_description,
                                h_discount_tax_rate,
                                h_charge_amount,
                                h_charge_description,
                                h_charge_tax_rate,
                                l_discount_amount,
                                l_discount_description,
                                l_charge_amount,
                                l_charge_description,
                                l_description_goods,
                                exchange_rate,
                                exchange_date,
                                original_currency_code,
                                created_by,
                                creation_date,
                                last_updated_by,
                                last_update_date,
                                last_update_login,
                                conc_request_id,
                                process_flag,
                                reprocess_flag,
                                extract_flag,
                                extract_date,
                                ERROR_CODE)
                     VALUES (i.invoice_id, remove_junk (i.invoice_number), i.invoice_date, i.payment_due_date, remove_junk (i.payment_term), 'EUR', lv_document_type, NULL, NULL, --i.SET_OF_BOOKS_ID
                                                                                                                                                                                  i.company, --i.COMPANY
                                                                                                                                                                                             i.routing_code, i.invoice_doc_reference, i.inv_doc_ref_desc, remove_junk (i.legal_entity_name), remove_junk (i.le_vat_number), remove_junk (i.legal_entity_address_street), i.legal_entity_address_postal_code, remove_junk (i.legal_entity_address_city), NVL (i.legal_entity_address_province, le_address_province), i.legal_entity_country, remove_junk (i.legal_entity_country_code), i.le_registriation_number, NVL (i.legal_entity_address_province, le_address_province), lv_company_reg_number, lv_share_capital, lv_status_share, lv_liquidation_number, remove_junk (i.buyer_name), remove_junk (i.buyer_vat_registration_number), remove_junk (i.buyer_address_street), i.buyer_address_postal_code, remove_junk (i.buyer_address_city), i.buyer_address_province, i.buyer_address_country, remove_junk (i.buyer_address_country_code), i.buyer_business_registration_number, DECODE (i.invoice_currency_code, 'EUR', DECODE (i.invoice_class, 'CM', ABS (l_h_tot_amount), l_h_tot_amount), TRUNC ((DECODE (i.invoice_class, 'CM', ABS (l_h_tot_amount), l_h_tot_amount) * i.exchange_rate), 2)) --h_total_tax_amount
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        , DECODE (i.invoice_currency_code, 'EUR', i.h_total_net_amount, TRUNC (ABS (i.h_total_net_amount * i.exchange_rate), 2)) -- h_total_net_amount
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                , DECODE (i.invoice_currency_code, 'EUR', i.h_total_net_amount_including_discount_charges, TRUNC ((i.h_total_net_amount_including_discount_charges * i.exchange_rate), 2)) --h_total_net_amount_including_discount_charges
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          , DECODE (i.invoice_currency_code, 'EUR', TRUNC ((i.h_total_net_amount + DECODE (i.invoice_class, 'CM', ABS (l_h_tot_amount), l_h_tot_amount)), 2), TRUNC ((ROUND ((i.h_total_net_amount + DECODE (i.invoice_class, 'CM', ABS (l_h_tot_amount), l_h_tot_amount)), 2) * i.exchange_rate), 2)) -- H_INVOICE_TOTAL
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      , DECODE (i.invoice_currency_code, 'EUR', DECODE (i.invoice_class, 'CM', ABS (TO_NUMBER (l_vat_net_amount)), TO_NUMBER (l_vat_net_amount)), TRUNC ((DECODE (i.invoice_class, 'CM', ABS (TO_NUMBER (l_vat_net_amount)), TO_NUMBER (l_vat_net_amount)) * i.exchange_rate), 2)) -- vat_net_amount
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  , TO_NUMBER (lv_final_tax_rate) --VAT_RATE
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 , DECODE (i.invoice_currency_code, 'EUR', DECODE (i.invoice_class, 'CM', ABS (TO_NUMBER (l_vat_amount)), TO_NUMBER (l_vat_amount)), TRUNC ((DECODE (i.invoice_class, 'CM', ABS (TO_NUMBER (l_vat_amount)), TO_NUMBER (l_vat_amount)) * i.exchange_rate), 2)) -- vat_amount
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             , DECODE (lv_final_tax_rate, 0, ld_tax_code, NULL) --TAX_CODE
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               , DECODE (lv_final_tax_rate, 0, lv_tax_exempt_desc, NULL) --lv_tax_exempt_desc
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        , remove_junk (i.invoice_description), i.unit_of_measure_code, i.quantity_invoiced, DECODE (i.invoice_currency_code, 'EUR', i.unit_price, TRUNC ((i.unit_price * i.exchange_rate), 2)), -- unit_price
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                i.l_vat_amount, DECODE (i.tax_code, 'SUPPRESS', 0, lv_final_tax_rate), --L_TAX_RATE
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       DECODE (i.vat_rate, 0, lv_tax_exempt_code, NULL), DECODE (i.invoice_currency_code, 'EUR', i.l_net_amount, ROUND ((i.l_net_amount * i.exchange_rate), 2)), -- net_amount
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 i.h_discount_amount, i.h_discount_description, i.h_discount_tax_rate, i.h_charge_amount, i.h_charge_description, i.h_charge_tax_rate, i.l_discount_amount, i.l_discount_description, i.l_charge_amount, i.l_charge_description, i.l_description_goods, DECODE (i.invoice_currency_code, 'EUR', NULL, i.exchange_rate), DECODE (i.invoice_currency_code, 'EUR', NULL, i.exchange_date), i.invoice_currency_code, gn_user_id, SYSDATE, gn_user_id, SYSDATE, gn_login_id, gn_request_id, 'N', pv_reprocess_flag
                             , NULL, NULL, NULL);
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           i.invoice_number
                        || 'Failed to insert the data into custom table:'
                        || SQLERRM);
            END;

            BEGIN
                IF ln_hdr_err_count = 1
                THEN
                    UPDATE xxdo.xxd_ar_ic_inv_stg
                       SET process_flag = 'E', extract_flag = 'N', ERROR_CODE = SUBSTR (LTRIM (lv_conc_error, ','), 1, 4000),
                           last_update_date = SYSDATE, last_updated_by = gn_user_id
                     WHERE     conc_request_id = gn_request_id
                           AND invoice_id = i.invoice_id;
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
        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'failed at insert_ap_eligible_recs exception');
            fnd_file.put_line (
                fnd_file.LOG,
                'Failed to insert the data into custom table:' || SQLERRM);
    END insert_ap_eligible_recs;

    PROCEDURE write_op_file (gn_request_id IN NUMBER, x_ret_code OUT VARCHAR2, x_ret_message OUT VARCHAR2)
    IS
        CURSOR get_hdr_cur IS
              SELECT UNIQUE hdr.invoice_id, hdr.invoice_number, hdr.company,
                            hdr.conc_request_id
                FROM xxdo.XXD_AR_IC_INV_STG hdr
               WHERE     1 = 1
                     AND hdr.conc_request_id = gn_request_id
                     AND hdr.process_flag = 'N'
                     --CCR0010417
                     AND NOT EXISTS
                             (SELECT 1
                                FROM xxdo.XXD_AR_IC_INV_STG line
                               WHERE     line.process_flag = 'E'
                                     AND line.invoice_id = hdr.invoice_id
                                     AND line.conc_request_id = gn_request_id)
            --
            GROUP BY hdr.invoice_id, hdr.invoice_number, hdr.company,
                     hdr.conc_request_id;

        CURSOR Cur_rec_select (p_invoice_id         NUMBER,
                               pv_Company           VARCHAR2,
                               pv_conc_request_id   NUMBER)
        IS
            SELECT DECODE (get_lookup_value ('INVOICE_ID', pv_Company), 'Y', STG.INVOICE_ID, '') || '||' || DECODE (get_lookup_value ('INVOICE_NUMBER', pv_Company), 'Y', STG.INVOICE_NUMBER, '') || '||' || DECODE (get_lookup_value ('INVOICE_DATE', pv_Company), 'Y', TO_CHAR (STG.INVOICE_DATE, 'DD-MON-YYYY'), '') || '||' || DECODE (get_lookup_value ('PAYMENT_DUE_DATE', pv_Company), 'Y', TO_CHAR (STG.PAYMENT_DUE_DATE, 'DD-MON-YYYY'), '') || '||' || DECODE (get_lookup_value ('PAYMENT_TERM', pv_Company), 'Y', TO_CHAR (STG.PAYMENT_DUE_DATE, 'DD-MON-YYYY'), '') || '||' || DECODE (get_lookup_value ('INVOICE_CURRENCY_CODE', pv_Company), 'Y', STG.INVOICE_CURRENCY_CODE, '') || '||' || DECODE (get_lookup_value ('DOCUMENT_TYPE', pv_Company), 'Y', STG.DOCUMENT_TYPE, '') || '||' || --     DECODE(get_lookup_value('DUTY_STAMP',pv_Company),'Y',STG.DUTY_STAMP,'')
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         --   ||'||'||
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         DECODE (get_lookup_value ('INVOICE_DOC_REFERENCE', pv_Company), 'Y', STG.INVOICE_DOC_REFERENCE, '') || '||' || DECODE (get_lookup_value ('INV_DOC_REF_DESC', pv_Company), 'Y', STG.INV_DOC_REF_DESC, '') || '||' || DECODE (get_lookup_value ('LEGAL_ENTITY_NAME', pv_Company), 'Y', STG.LEGAL_ENTITY_NAME, '') || '||' || DECODE (get_lookup_value ('LEGAL_ENTITY_ADDRESS_STREET', pv_Company), 'Y', STG.LEGAL_ENTITY_ADDRESS_STREET, '') || '||' || DECODE (get_lookup_value ('LEGAL_ENTITY_ADDRESS_POSTAL_CODE', pv_Company), 'Y', STG.LEGAL_ENTITY_ADDRESS_POSTAL_CODE, '') || '||' || DECODE (get_lookup_value ('LEGAL_ENTITY_ADDRESS_CITY', pv_Company), 'Y', STG.LEGAL_ENTITY_ADDRESS_CITY, '') || '||' || DECODE (get_lookup_value ('LEGAL_ENTITY_ADDRESS_PROVINCE', pv_Company), 'Y', STG.LEGAL_ENTITY_ADDRESS_PROVINCE, '') || '||' || DECODE (get_lookup_value ('LEGAL_ENTITY_COUNTRY', pv_Company), 'Y', STG.LEGAL_ENTITY_COUNTRY, '') || '||' || DECODE (get_lookup_value ('LEGAL_ENTITY_COUNTRY_CODE', pv_Company), 'Y', STG.LEGAL_ENTITY_COUNTRY_CODE, '') || '||' || DECODE (get_lookup_value ('LE_VAT_NUMBER', pv_Company), 'Y', STG.LE_VAT_NUMBER, '') || '||' || DECODE (get_lookup_value ('LE_REGISTRIATION_NUMBER', pv_Company), 'Y', STG.LE_REGISTRIATION_NUMBER, '') || '||' || DECODE (get_lookup_value ('PROVINCE_REG_OFFICE', pv_Company), 'Y', STG.PROVINCE_REG_OFFICE, '') || '||' || DECODE (get_lookup_value ('COMPANY_REG_NUMBER', pv_Company), 'Y', STG.COMPANY_REG_NUMBER, '') || '||' || DECODE (get_lookup_value ('SHARE_CAPITAL', pv_Company), 'Y', STG.SHARE_CAPITAL, '') || '||' || DECODE (get_lookup_value ('STATUS_SHAREHOLDERS', pv_Company), 'Y', STG.STATUS_SHAREHOLDERS, '') || '||' || DECODE (get_lookup_value ('LIQUIDATION_STATUS', pv_Company), 'Y', STG.LIQUIDATION_STATUS, '') || '||' || DECODE (get_lookup_value ('BUYER_NAME', pv_Company), 'Y', STG.BUYER_NAME, '') || '||' || DECODE (get_lookup_value ('BUYER_ADDRESS_STREET', pv_Company), 'Y', STG.BUYER_ADDRESS_STREET, '') || '||' || DECODE (get_lookup_value ('BUYER_ADDRESS_POSTAL_CODE', pv_Company), 'Y', STG.BUYER_ADDRESS_POSTAL_CODE, '') || '||' || DECODE (get_lookup_value ('BUYER_ADDRESS_CITY', pv_Company), 'Y', STG.BUYER_ADDRESS_CITY, '') || '||' || DECODE (get_lookup_value ('BUYER_ADDRESS_PROVINCE', pv_Company), 'Y', STG.BUYER_ADDRESS_PROVINCE, '') || '||' || DECODE (get_lookup_value ('BUYER_ADDRESS_COUNTRY', pv_Company), 'Y', STG.BUYER_ADDRESS_COUNTRY, '') || '||' || DECODE (get_lookup_value ('BUYER_ADDRESS_COUNTRY_CODE', pv_Company), 'Y', STG.BUYER_ADDRESS_COUNTRY_CODE, '') || '||' || DECODE (get_lookup_value ('BUYER_VAT_NUMBER', pv_Company), 'Y', STG.BUYER_VAT_NUMBER, '') || '||' || DECODE (get_lookup_value ('BUYER_BUSINESS_REGISTRATION_NUMBER', pv_Company), 'Y', STG.BUYER_BUSINESS_REGISTRATION_NUMBER, '') || '||' || DECODE (get_lookup_value ('ROUTING_CODE', pv_Company), 'Y', STG.ROUTING_CODE, '') || '||' || DECODE (get_lookup_value ('H_TOTAL_TAX_AMOUNT', pv_Company), 'Y', STG.H_TOTAL_TAX_AMOUNT, '') || '||' || DECODE (get_lookup_value ('H_TOTAL_NET_AMOUNT', pv_Company), 'Y', STG.H_TOTAL_NET_AMOUNT, '') || '||' || DECODE (get_lookup_value ('H_TOTAL_NET_AMOUNT_INCLUDING_DISCOUNT_CHARGES', pv_Company), 'Y', STG.H_TOTAL_NET_AMOUNT_INCLUDING_DISCOUNT_CHARGES, '') || '||' || DECODE (get_lookup_value ('H_INVOICE_TOTAL', pv_Company), 'Y', STG.H_INVOICE_TOTAL, '') || '||' || DECODE (get_lookup_value ('VAT_NET_AMOUNT', pv_Company), 'Y', STG.VAT_NET_AMOUNT, '') || '||' || DECODE (get_lookup_value ('VAT_RATE', pv_Company), 'Y', STG.VAT_RATE, '') || '||' || DECODE (get_lookup_value ('VAT_AMOUNT', pv_Company), 'Y', STG.VAT_AMOUNT, '') || '||' || DECODE (get_lookup_value ('TAX_CODE', pv_Company),  'Y', STG.TAX_CODE,  'C', STG.TAX_CODE,  '') || '||' || DECODE (get_lookup_value ('TAX_EXEMPTION_DESCRIPTION', pv_Company),  'Y', STG.TAX_EXEMPTION_DESCRIPTION,  'C', STG.TAX_EXEMPTION_DESCRIPTION,  '') || '||' || DECODE (get_lookup_value ('INVOICE_DESCRIPTION', pv_Company), 'Y', STG.Invoice_Description, '') || '||' || DECODE (get_lookup_value ('UNIT_OF_MEASURE_CODE', pv_Company), 'Y', STG.UNIT_OF_MEASURE_CODE, '') || '||' || DECODE (get_lookup_value ('QUANTITY_INVOICED', pv_Company), 'Y', STG.QUANTITY_INVOICED, '') || '||' || DECODE (get_lookup_value ('UNIT_PRICE', pv_Company), 'Y', STG.UNIT_PRICE, '') || '||' || DECODE (get_lookup_value ('L_VAT_AMOUNT', pv_Company), 'Y', STG.L_VAT_AMOUNT, '') || '||' || DECODE (get_lookup_value ('L_TAX_RATE', pv_Company), 'Y', STG.L_TAX_RATE, '') || '||' || DECODE (get_lookup_value ('L_TAX_EXEMPTION_CODE', pv_Company),  'Y', STG.L_TAX_EXEMPTION_CODE,  'C', STG.L_TAX_EXEMPTION_CODE,  '') || '||' || DECODE (get_lookup_value ('L_NET_AMOUNT', pv_Company), 'Y', STG.L_NET_AMOUNT, '') || '||' || DECODE (get_lookup_value ('H_DISCOUNT_AMOUNT', pv_Company), 'Y', STG.H_DISCOUNT_AMOUNT, '') || '||' || DECODE (get_lookup_value ('H_DISCOUNT_DESCRIPTION', pv_Company), 'Y', STG.H_DISCOUNT_DESCRIPTION, '') || '||' || DECODE (get_lookup_value ('H_DISCOUNT_TAX_RATE', pv_Company), 'Y', STG.H_DISCOUNT_TAX_RATE, '') || '||' || DECODE (get_lookup_value ('H_CHARGE_AMOUNT', pv_Company), 'Y', STG.H_CHARGE_AMOUNT, '') || '||' || DECODE (get_lookup_value ('H_CHARGE_DESCRIPTION', pv_Company), 'Y', STG.H_CHARGE_DESCRIPTION, '') || '||' || DECODE (get_lookup_value ('H_CHARGE_TAX_RATE', pv_Company), 'Y', STG.H_CHARGE_TAX_RATE, '') || '||' || DECODE (get_lookup_value ('L_DISCOUNT_AMOUNT', pv_Company), 'Y', STG.L_DISCOUNT_AMOUNT, '') || '||' || DECODE (get_lookup_value ('L_DISCOUNT_DESCRIPTION', pv_Company), 'Y', STG.L_DISCOUNT_DESCRIPTION, '') || '||' || DECODE (get_lookup_value ('L_CHARGE_AMOUNT', pv_Company), 'Y', STG.L_CHARGE_AMOUNT, '') || '||' || DECODE (get_lookup_value ('L_CHARGE_DESCRIPTION', pv_Company), 'Y', STG.L_CHARGE_DESCRIPTION, '') || '||' || DECODE (get_lookup_value ('L_DESCRIPTION_GOODS', pv_Company), 'Y', STG.L_DESCRIPTION_GOODS, '') || '||' || DECODE (get_lookup_value ('EXCHANGE_RATE', pv_Company), 'Y', STG.EXCHANGE_RATE, '') || '||' || DECODE (get_lookup_value ('EXCHANGE_DATE', pv_Company), 'Y', TO_CHAR (STG.EXCHANGE_DATE, 'DD-MON-YYYY'), '') || '||' || DECODE (get_lookup_value ('ORIGINAL_CURRENCY_CODE', pv_Company), 'Y', STG.ORIGINAL_CURRENCY_CODE, '') line
              FROM XXDO.XXD_AR_IC_INV_STG STG
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
                   'ICAR'
                || i.invoice_number
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
                --     ||'DUTY_STAMP'
                --   || '||'
                || 'INVOICE_DOC_REFERENCE'
                || '||'
                || 'INV_DOC_REF_DESC'
                || '||'
                || 'LEGAL_ENTITY_NAME'
                || '||'
                || 'LEGAL_ENTITY_ADDRESS_STREET'
                || '||'
                || 'LEGAL_ENTITY_ADDRESS_POSTAL_CODE'
                || '||'
                || 'LEGAL_ENTITY_ADDRESS_CITY'
                || '||'
                || 'LEGAL_ENTITY_ADDRESS_PROVINCE'
                || '||'
                || 'LEGAL_ENTITY_COUNTRY'
                || '||'
                || 'LEGAL_ENTITY_COUNTRY_CODE'
                || '||'
                || 'LE_VAT_NUMBER'
                || '||'
                || 'LE_REGISTRIATION_NUMBER'
                || '||'
                || 'PROVINCE_REG_OFFICE'
                || '||'
                || 'COMPANY_REG_NUMBER'
                || '||'
                || 'SHARE_CAPITAL'
                || '||'
                || 'STATUS_SHAREHOLDERS'
                || '||'
                || 'LIQUIDATION_STATUS'
                || '||'
                || 'BUYER_NAME'
                || '||'
                || 'BUYER_ADDRESS_STREET'
                || '||'
                || 'BUYER_ADDRESS_POSTAL_CODE'
                || '||'
                || 'BUYER_ADDRESS_CITY'
                || '||'
                || 'BUYER_ADDRESS_PROVINCE'
                || '||'
                || 'BUYER_ADDRESS_COUNTRY'
                || '||'
                || 'BUYER_ADDRESS_COUNTRY_CODE'
                || '||'
                || 'BUYER_VAT_NUMBER'
                || '||'
                || 'BUYER_BUSINESS_REGISTRATION_NUMBER'
                || '||'
                || 'ROUTING_CODE'
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
                || 'TAX_EXEMPTION_DESCRIPTION'
                || '||'
                || 'INVOICE_DESCRIPTION'
                || '||'
                || 'UNIT_OF_MEASURE_CODE'
                || '||'
                || 'QUANTITY_INVOICED'
                || '||'
                || 'UNIT_PRICE'
                || '||'
                || 'L_VAT_AMOUNT'
                || '||'
                || 'L_TAX_RATE'
                || '||'
                || 'L_TAX_EXEMPTION_CODE'
                || '||'
                || 'L_NET_AMOUNT'
                || '||'
                || 'H_DISCOUNT_AMOUNT'
                || '||'
                || 'H_DISCOUNT_DESCRIPTION'
                || '||'
                || 'H_DISCOUNT_TAX_RATE'
                || '||'
                || 'H_CHARGE_AMOUNT'
                || '||'
                || 'H_CHARGE_DESCRIPTION'
                || '||'
                || 'H_CHARGE_TAX_RATE'
                || '||'
                || 'L_DISCOUNT_AMOUNT'
                || '||'
                || 'L_DISCOUNT_DESCRIPTION'
                || '||'
                || 'L_CHARGE_AMOUNT'
                || '||'
                || 'L_CHARGE_DESCRIPTION'
                || '||'
                || 'L_DESCRIPTION_GOODS'
                || '||'
                || 'EXCHANGE_RATE'
                || '||'
                || 'EXCHANGE_DATE'
                || '||'
                || 'ORIGINAL_CURRENCY_CODE';

            apps.fnd_file.put_line (fnd_file.output, lv_line);

            lv_output_file   :=
                UTL_FILE.fopen ('XXD_AR_SDI_IC_OUT_DIR', lv_file_name, 'W' --opening the file in write mode
                                                                          ,
                                32767);


            IF UTL_FILE.is_open (lv_output_file)
            THEN
                apps.fnd_file.put_line (fnd_file.LOG, 'File is Open');
                UTL_FILE.put_line (lv_output_file, 'Deckers');
                UTL_FILE.put_line (lv_output_file,
                                   'E-Invoicing Pagero Crossborder');
                UTL_FILE.put_line (
                    lv_output_file,
                       'AR IC Export - Run Date of '
                    || TO_CHAR (SYSDATE, 'DD-MON-YYYY'));
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
                UPDATE xxdo.XXD_AR_IC_INV_STG
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

            -- updating extract flag and date in IC table
            BEGIN
                UPDATE XXCP_IC_INV_HEADER
                   SET extract_flag = 'Y', extract_date = SYSDATE
                 WHERE invoice_header_id = i.invoice_Id;
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

    PROCEDURE main (errbuf OUT NOCOPY VARCHAR2, retcode OUT NOCOPY VARCHAR2, pv_company_segment IN VARCHAR2, pv_reprocess_flag IN VARCHAR2, pv_inv_enabled_tmp IN VARCHAR2, pv_invoice_num IN NUMBER
                    , pv_end_date IN VARCHAR2)
    AS
        --Define Variables
        lv_ret_code           VARCHAR2 (30) := NULL;
        lv_ret_message        VARCHAR2 (2000) := NULL;
        l_inv_from_date       DATE;
        l_inv_to_date         DATE;
        lv_begin_date         DATE;
        lv_end_date           DATE;
        lv_invoice_end_date   DATE;
        l_period_num          VARCHAR2 (10);
        ln_ledger_id          NUMBER;
        lv_period_status      VARCHAR2 (10);
    BEGIN
        -- Printing all the parameters
        fnd_file.put_line (
            fnd_file.LOG,
            'Deckers AR Intercompany Invoice Outbound Integration Program.....');
        fnd_file.put_line (fnd_file.LOG, 'Parameters Are.....');
        fnd_file.put_line (fnd_file.LOG, '-------------------');
        fnd_file.put_line (fnd_file.LOG,
                           'pv_company_segment:' || pv_company_segment);
        fnd_file.put_line (fnd_file.LOG,
                           'pv_reprocess_flag   :' || pv_reprocess_flag);
        fnd_file.put_line (fnd_file.LOG,
                           'pv_invoice_number    :' || pv_invoice_num);
        fnd_file.put_line (fnd_file.LOG, 'pv_end_date    :' || pv_end_date);

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

        --

        IF NVL (pv_reprocess_flag, 'N') = 'Y' AND pv_invoice_num IS NOT NULL
        THEN
            l_inv_from_date   := NULL;
            l_inv_to_date     := l_inv_to_date;                 --lv_end_date;
        ELSIF NVL (pv_reprocess_flag, 'N') = 'Y' AND pv_invoice_num IS NULL
        THEN
            l_inv_from_date   := l_inv_from_date;             --lv_begin_date;
            l_inv_to_date     := l_inv_to_date;                 --lv_end_date;
        ELSIF     NVL (pv_reprocess_flag, 'N') = 'N'
              AND pv_invoice_num IS NOT NULL
        THEN
            --lv_from_date := lv_begin_date;
            l_inv_to_date   := l_inv_to_date;                   --lv_end_date;
        ELSIF NVL (pv_reprocess_flag, 'N') = 'N' AND pv_invoice_num IS NULL
        THEN
            l_inv_from_date   := l_inv_from_date;             --lv_begin_date;
            l_inv_to_date     := l_inv_to_date;                 --lv_end_date;
        END IF;

        --Insert data into Staging tables
        insert_ar_eligible_recs (pv_company_segment => pv_company_segment, pv_reprocess_flag => pv_reprocess_flag, pv_invoice_num => pv_invoice_num, pv_from_date => l_inv_from_date, pv_to_date => l_inv_to_date, x_ret_code => lv_ret_code
                                 , x_ret_message => lv_ret_message);

        insert_ap_eligible_recs (pv_company_segment => pv_company_segment, pv_reprocess_flag => pv_reprocess_flag, pv_invoice_num => pv_invoice_num, pv_from_date => l_inv_from_date, pv_to_date => l_inv_to_date, x_ret_code => lv_ret_code
                                 , x_ret_message => lv_ret_message);

        write_op_file (gn_request_id   => gn_request_id,
                       x_ret_code      => lv_ret_code,
                       x_ret_message   => lv_ret_message);

        generate_report_prc (p_conc_request_id => gn_request_id);
    EXCEPTION
        WHEN OTHERS
        THEN
            print_log ('Error occured in main procedure' || SQLERRM);
    END main;
END XXD_AR_IC_INV_OUTBOUND_PKG;
/
