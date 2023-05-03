--
-- XXD_AP_NT_PROCURE_EXT_SPND_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:31:44 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_AP_NT_PROCURE_EXT_SPND_PKG"
AS
    -- ####################################################################################################################
    -- Package      : XXD_AP_NT_PROCURE_EXT_SPND_PKG
    -- Design       : This package will be used by the Deckers Non-Trade Procurement External Spend Report
    --
    -- Modification :
    -- ----------
    -- Date            Name               Ver    Description
    -- ----------      --------------    -----  ------------------
    -- 20-Jan-2023     Jayarajan A K      1.0    Initial Version (CCR0010397)
    -- #########################################################################################################################

    --  insert_message procedure
    PROCEDURE insrt_msg (pv_message_type   IN VARCHAR2,
                         pv_message        IN VARCHAR2,
                         pv_debug          IN VARCHAR2 := 'N')
    AS
    BEGIN
        IF UPPER (pv_message_type) IN ('LOG', 'BOTH') AND pv_debug = 'Y'
        THEN
            fnd_file.put_line (fnd_file.LOG, pv_message);
        END IF;

        IF UPPER (pv_message_type) IN ('OUTPUT', 'BOTH')
        THEN
            fnd_file.put_line (fnd_file.output, pv_message);
        END IF;

        IF UPPER (pv_message_type) = 'DATABASE'
        THEN
            DBMS_OUTPUT.put_line (pv_message);
        END IF;
    END insrt_msg;

    --This function returns the translated value for the given field
    FUNCTION get_trans_val (pv_field IN VARCHAR2)
        RETURN VARCHAR2
    IS
    BEGIN
        RETURN TRANSLATE (pv_field,
                          CHR (9) || CHR (10) || CHR (13) || '\/:*?"<>|,',
                          '-------------');
    EXCEPTION
        WHEN OTHERS
        THEN
            insrt_msg ('LOG',
                       'Error in get_trans_val function: ' || SQLERRM,
                       'Y');
            RETURN pv_field;
    END get_trans_val;


    PROCEDURE generate_report (x_msg                 OUT VARCHAR2,
                               x_ret_stat            OUT VARCHAR2,
                               p_inv_start_date   IN     VARCHAR2,
                               p_inv_end_date     IN     VARCHAR2,
                               p_debug            IN     VARCHAR2)
    AS
        CURSOR report_cur (p_inv_start_dt IN DATE, p_inv_end_dt IN DATE)
        IS
            SELECT *
              FROM (WITH
                        ap
                        AS
                            (SELECT hou.name
                                        ou,
                                    asu.vendor_name
                                        vendor,
                                    asu.segment1
                                        vendor_num,
                                    assa.vendor_site_code
                                        vendor_site,
                                       assa.address_line1
                                    || ' '
                                    || NVL (assa.address_line2, ' ')
                                    || assa.city
                                    || ' '
                                    || assa.state
                                    || ' '
                                    || assa.zip
                                    || ' '
                                    || assa.country
                                        vendor_addr,
                                    TO_CHAR (aia.invoice_date, 'MM/DD/YYYY')
                                        inv_date,
                                    TO_CHAR (aia.creation_date, 'MM/DD/YYYY')
                                        inv_cre_date,
                                    TO_CHAR (aps.due_date, 'MM/DD/YYYY')
                                        inv_due_date,
                                    TO_CHAR (aia.invoice_num)
                                        inv_num,
                                    aia.invoice_amount
                                        inv_tot,
                                    DECODE (
                                        aia.invoice_currency_code,
                                        'USD', aia.invoice_amount,
                                        (SELECT ROUND (aia.invoice_amount * gdr.conversion_rate, 2)
                                           FROM gl_daily_rates gdr
                                          WHERE     gdr.conversion_type =
                                                    'Corporate'
                                                AND gdr.conversion_date =
                                                    aia.invoice_date
                                                AND aia.invoice_currency_code =
                                                    gdr.from_currency
                                                AND gdr.to_currency = 'USD'))
                                        inv_tot_usd,
                                    aia.description
                                        inv_desc,
                                    ap_gcc.segment1
                                        ap_gl_comp,
                                    gl_flexfields_pkg.get_description_sql (
                                        50388,
                                        1,
                                        ap_gcc.segment1)
                                        ap_gl_comp_name,
                                    ap_gcc.segment2
                                        ap_gl_brand,
                                    gl_flexfields_pkg.get_description_sql (
                                        50388,
                                        2,
                                        ap_gcc.segment2)
                                        ap_gl_brand_name,
                                    ap_gcc.segment3
                                        ap_gl_geo,
                                    gl_flexfields_pkg.get_description_sql (
                                        50388,
                                        3,
                                        ap_gcc.segment3)
                                        ap_gl_geo_name,
                                    ap_gcc.segment4
                                        ap_gl_chan,
                                    gl_flexfields_pkg.get_description_sql (
                                        50388,
                                        4,
                                        ap_gcc.segment4)
                                        ap_gl_chan_name,
                                    ap_gcc.segment5
                                        ap_gl_cc,
                                    gl_flexfields_pkg.get_description_sql (
                                        50388,
                                        5,
                                        ap_gcc.segment5)
                                        ap_gl_cc_name,
                                    ap_gcc.segment6
                                        ap_gl_nat,
                                    gl_flexfields_pkg.get_description_sql (
                                        50388,
                                        6,
                                        ap_gcc.segment6)
                                        ap_gl_nat_name,
                                    TO_CHAR (aila.accounting_date,
                                             'MM/DD/YYYY')
                                        acc_date,
                                    DECODE (
                                        aia.invoice_currency_code,
                                        'USD', 1,
                                        (SELECT gdr.conversion_rate
                                           FROM gl_daily_rates gdr
                                          WHERE     gdr.conversion_type =
                                                    'Corporate'
                                                AND gdr.conversion_date =
                                                    aia.invoice_date
                                                AND aia.invoice_currency_code =
                                                    gdr.from_currency
                                                AND gdr.to_currency = 'USD'))
                                        conv_rate,
                                    aida.cash_posted_flag
                                        post_flag,
                                    aida.description
                                        dist_desc,
                                    aida.distribution_line_number
                                        dist_line_num,
                                    TO_CHAR (aia.gl_date, 'MM/DD/YYYY')
                                        gl_date,
                                    aia.invoice_currency_code
                                        inv_curr,
                                    TO_CHAR (aia.last_update_date,
                                             'MM/DD/YYYY')
                                        inv_upd_date,
                                    (SELECT fu.user_name
                                       FROM fnd_user fu
                                      WHERE fu.user_id = aia.last_updated_by)
                                        inv_upd_by,
                                    aia.source
                                        inv_source,
                                    DECODE (
                                        ap_invoices_utility_pkg.get_approval_status (
                                            aia.invoice_id,
                                            aia.invoice_amount,
                                            aia.payment_status_flag,
                                            aia.invoice_type_lookup_code),
                                        'FULL', 'Fully Applied',
                                        'NEVER APPROVED', 'Never Validated',
                                        'NEEDS REAPPROVAL', 'Needs Revalidation',
                                        'CANCELLED', 'Cancelled',
                                        'UNPAID', 'Unpaid',
                                        'AVAILABLE', 'Available',
                                        'UNAPPROVED', 'Unvalidated',
                                        'APPROVED', 'Validated',
                                        'PERMANENT', 'Permanent Prepayment',
                                        NULL)
                                        inv_status,
                                    aila.line_number
                                        line_num,
                                    aila.line_source
                                        line_source,
                                    aila.amount
                                        line_amt,
                                    DECODE (
                                        aia.invoice_currency_code,
                                        'USD', aila.amount,
                                        (SELECT ROUND (aila.amount * gdr.conversion_rate, 2)
                                           FROM gl_daily_rates gdr
                                          WHERE     gdr.conversion_type =
                                                    'Corporate'
                                                AND gdr.conversion_date =
                                                    aia.invoice_date
                                                AND aia.invoice_currency_code =
                                                    gdr.from_currency
                                                AND gdr.to_currency = 'USD'))
                                        line_amt_usd,
                                    aps.payment_method_code
                                        pay_method,
                                    aps.payment_status_flag
                                        pay_status_flag,
                                    DECODE (aps.payment_status_flag,
                                            'N', 'Not Paid',
                                            'P', 'Partially Paid',
                                            'Y', 'Fully Paid',
                                            aps.payment_status_flag)
                                        pay_status,
                                    aida.reversal_flag
                                        rev_flag,
                                    TO_CHAR (aia.terms_date, 'MM/DD/YYYY')
                                        terms_date,
                                    (SELECT ats.name
                                       FROM ap_terms ats
                                      WHERE ats.term_id = aia.terms_id)
                                        terms_name,
                                    aida.amount
                                        dist_amt,
                                    DECODE (
                                        aia.invoice_currency_code,
                                        'USD', aida.amount,
                                        (SELECT ROUND (aida.amount * gdr.conversion_rate, 2)
                                           FROM gl_daily_rates gdr
                                          WHERE     gdr.conversion_type =
                                                    'Corporate'
                                                AND gdr.conversion_date =
                                                    aia.invoice_date
                                                AND aia.invoice_currency_code =
                                                    gdr.from_currency
                                                AND gdr.to_currency = 'USD'))
                                        dist_amt_usd,
                                    aida.po_distribution_id,
                                    aia.vendor_id,
                                    aia.vendor_site_id
                               FROM ap.ap_invoices_all aia, ap_invoice_lines_all aila, ap_invoice_distributions_all aida,
                                    ap_suppliers asu, ap_supplier_sites_all assa, hr_operating_units hou,
                                    ap_payment_schedules_all aps, gl_code_combinations ap_gcc
                              WHERE     aia.invoice_id = aia.invoice_id
                                    AND aia.invoice_id = aila.invoice_id
                                    AND aida.invoice_id = aia.invoice_id
                                    AND aida.invoice_line_number =
                                        aila.line_number
                                    AND aia.vendor_id = asu.vendor_id
                                    AND aia.vendor_site_id =
                                        assa.vendor_site_id
                                    AND aia.org_id = hou.organization_id
                                    AND aps.invoice_id = aia.invoice_id
                                    AND ap_gcc.code_combination_id =
                                        aida.dist_code_combination_id
                                    AND aida.po_distribution_id IS NOT NULL
                                    AND aia.creation_date >= p_inv_start_dt
                                    AND aia.creation_date < p_inv_end_dt + 1),
                        pda
                        AS
                            (SELECT ap.*,
                                    prha.segment1
                                        req_num,
                                    (SELECT MIN (papf.full_name)
                                       FROM per_all_people_f papf
                                      WHERE papf.person_id = prha.preparer_id)
                                        preparer,
                                    (SELECT MIN (papf.full_name)
                                       FROM per_all_people_f papf
                                      WHERE papf.person_id =
                                            prla.to_person_id)
                                        requester,
                                    prla.requester_email,
                                    (SELECT MIN (papf.full_name)
                                       FROM po_action_history pah, per_all_people_f papf
                                      WHERE     prha.requisition_header_id =
                                                pah.object_id
                                            AND papf.person_id =
                                                pah.employee_id
                                            AND pah.object_type_code =
                                                'REQUISITION')
                                        req_appr,
                                    pda.po_header_id,
                                    pda.po_line_id,
                                    pda.req_distribution_id,
                                    pda.amount_billed
                                        po_dist_amt,
                                    po_gcc.segment1
                                        po_gl_comp,
                                    gl_flexfields_pkg.get_description_sql (
                                        50388,
                                        1,
                                        po_gcc.segment1)
                                        po_gl_comp_name,
                                    po_gcc.segment2
                                        po_gl_brand,
                                    gl_flexfields_pkg.get_description_sql (
                                        50388,
                                        2,
                                        po_gcc.segment2)
                                        po_gl_brand_name,
                                    po_gcc.segment3
                                        po_gl_geo,
                                    gl_flexfields_pkg.get_description_sql (
                                        50388,
                                        3,
                                        po_gcc.segment3)
                                        po_gl_geo_name,
                                    po_gcc.segment4
                                        po_gl_chan,
                                    gl_flexfields_pkg.get_description_sql (
                                        50388,
                                        4,
                                        po_gcc.segment4)
                                        po_gl_chan_name,
                                    po_gcc.segment5
                                        po_gl_cc,
                                    gl_flexfields_pkg.get_description_sql (
                                        50388,
                                        5,
                                        po_gcc.segment5)
                                        po_gl_cc_name,
                                    po_gcc.segment6
                                        po_gl_nat,
                                    gl_flexfields_pkg.get_description_sql (
                                        50388,
                                        6,
                                        po_gcc.segment6)
                                        po_gl_nat_name
                               FROM po_distributions_all pda, po_req_distributions_all prda, po_requisition_lines_all prla,
                                    po_requisition_headers_all prha, gl_code_combinations po_gcc, ap
                              WHERE     1 = 1
                                    AND pda.po_distribution_id =
                                        ap.po_distribution_id
                                    AND pda.req_distribution_id =
                                        prda.distribution_id
                                    AND prda.requisition_line_id =
                                        prla.requisition_line_id
                                    AND prla.requisition_header_id =
                                        prha.requisition_header_id
                                    AND prla.requisition_header_id =
                                        prha.requisition_header_id
                                    AND po_gcc.code_combination_id =
                                        pda.code_combination_id),
                        po
                        AS
                            (SELECT pda.*,
                                    pha.segment1
                                        po,
                                    pha.closed_code
                                        po_status,
                                    pha.authorization_status
                                        po_appr_status,
                                    TO_CHAR (pha.creation_date, 'MM/DD/YYYY')
                                        po_crea_date,
                                    TO_CHAR (pha.approved_date, 'MM/DD/YYYY')
                                        po_appr_date,
                                    (SELECT hlat.location_code
                                       FROM hr_locations_all_tl hlat
                                      WHERE     language = USERENV ('LANG')
                                            AND location_id =
                                                pha.ship_to_location_id)
                                        ship_to,
                                    (SELECT hlat.location_code
                                       FROM hr_locations_all_tl hlat
                                      WHERE     language = USERENV ('LANG')
                                            AND location_id =
                                                pha.bill_to_location_id)
                                        bill_to,
                                    pla.line_num
                                        po_line_num,
                                    pla.item_description
                                        itm_desc,
                                    pla.cancel_flag
                                        can_flag,
                                    DECODE (
                                        pha.currency_code,
                                        'USD', pda.po_dist_amt,
                                        (SELECT ROUND (pda.po_dist_amt * gdr.conversion_rate, 2)
                                           FROM gl_daily_rates gdr
                                          WHERE     gdr.conversion_type =
                                                    'Corporate'
                                                AND gdr.conversion_date =
                                                    TO_DATE (pda.inv_date,
                                                             'MM/DD/YYYY')
                                                AND pha.currency_code =
                                                    gdr.from_currency
                                                AND gdr.to_currency = 'USD'))
                                        po_dist_amt_usd,
                                    (SELECT MIN (papf.full_name)
                                       FROM per_all_people_f papf
                                      WHERE papf.person_id = pha.agent_id)
                                        buyer_name,
                                    (SELECT mcv.category_concat_segs
                                       FROM mtl_categories_v mcv
                                      WHERE mcv.category_id = pla.category_id)
                                        po_itm_cat
                               FROM po_headers_all pha, po_lines_all pla, pda
                              WHERE     1 = 1
                                    AND pha.po_header_id = pla.po_header_id
                                    AND pha.po_header_id = pda.po_header_id
                                    AND pla.po_line_id = pda.po_line_id
                                    AND pha.vendor_id = pda.vendor_id
                                    AND pha.vendor_site_id =
                                        pda.vendor_site_id
                                    AND pha.attribute10 = 'NON_TRADE')
                    SELECT ou operating_unit, vendor, vendor_num,
                           vendor_site, vendor_addr vendor_address, inv_num invoice_number,
                           inv_desc invoice_description, inv_source invoice_source, inv_date invoice_date,
                           acc_date accounting_date, gl_date, inv_due_date invoice_due_date,
                           inv_cre_date invoice_creation_date, inv_upd_date invoice_last_update_date, inv_upd_by invoice_last_update_by,
                           inv_curr invoice_currency, inv_tot invoice_total, inv_tot_usd invoice_total_usd,
                           conv_rate conversion_rate, inv_status invoice_status, line_num invoice_line_number,
                           line_source invoice_line_source, line_amt invoice_line_amount, line_amt_usd invoice_line_amount_usd,
                           pay_method payment_method, pay_status_flag payment_status_flag, pay_status payment_status,
                           rev_flag reversal_flag, terms_date, terms_name,
                           post_flag posted_flag, dist_desc distribution_description, dist_line_num distribution_line_number,
                           dist_amt invoice_distribution_amount, dist_amt_usd invoice_distribution_amount_usd, ap_gl_comp ap_gl_company_code,
                           ap_gl_comp_name ap_gl_company_name, ap_gl_brand ap_gl_brand_code, ap_gl_brand_name ap_gl_brand_name,
                           ap_gl_geo ap_gl_geo_code, ap_gl_geo_name ap_gl_geo_name, ap_gl_chan ap_gl_channel_code,
                           ap_gl_chan_name ap_gl_channel_name, ap_gl_cc ap_gl_cost_center_code, ap_gl_cc_name ap_gl_cost_center_name,
                           ap_gl_nat ap_gl_natural_account_code, ap_gl_nat_name ap_gl_natural_account_name, req_num requisition_number,
                           preparer, requester, requester_email,
                           req_appr requisition_approver, po po_number, buyer_name,
                           po_status, po_appr_status po_approval_status, po_crea_date po_creation_date,
                           po_appr_date po_approval_date, ship_to ship_to_address, bill_to bill_to_address,
                           po_line_num po_line_number, itm_desc item_description, po_itm_cat item_category,
                           can_flag po_cancel_flag, po_dist_amt po_distribution_amount, po_dist_amt_usd po_distribution_amount_usd,
                           po_gl_comp po_gl_company_code, po_gl_comp_name po_gl_company_name, po_gl_brand po_gl_brand_code,
                           po_gl_brand_name po_gl_brand_name, po_gl_geo po_gl_geo_code, po_gl_geo_name po_gl_geo_name,
                           po_gl_chan po_gl_channel_code, po_gl_chan_name po_gl_channel_name, po_gl_cc po_gl_cost_center_code,
                           po_gl_cc_name po_gl_cost_center_name, po_gl_nat po_gl_natural_account_code, po_gl_nat_name po_gl_natural_account_name
                      FROM po);

        TYPE rprt_type IS TABLE OF report_cur%ROWTYPE;

        v_rprt_type         rprt_type := rprt_type ();

        ln_limit            NUMBER := 30000;
        lt_output_file      UTL_FILE.file_type;
        lv_file_name        VARCHAR2 (100) := 'GLOBAL_SPEND.csv';
        lv_directory_path   VARCHAR2 (1000);
        lv_line             VARCHAR2 (32767) := NULL;
        lv_mail_delimiter   VARCHAR2 (1) := '/';
        lv_file_delimiter   VARCHAR2 (1) := ',';
        lv_full_file_name   VARCHAR2 (1000);
        ln_count            NUMBER := 0;
        lv_start_date       DATE;
        lv_end_date         DATE;
    BEGIN
        insrt_msg ('LOG', 'Inside generate_report Procedure', 'Y');

        BEGIN
            lv_directory_path   := NULL;

            SELECT directory_path
              INTO lv_directory_path
              FROM dba_directories
             WHERE 1 = 1 AND directory_name = 'XXD_AP_SPN_DIR';

            insrt_msg ('LOG',
                       'lv_directory_path: ' || lv_directory_path,
                       p_debug);
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_directory_path   := NULL;
        END;

        v_rprt_type.delete;

        lv_full_file_name   :=
            lv_directory_path || lv_mail_delimiter || lv_file_name;

        insrt_msg ('LOG',
                   'lv_full_file_name: ' || lv_full_file_name,
                   p_debug);

        lt_output_file   :=
            UTL_FILE.fopen ('XXD_AP_SPN_DIR', lv_file_name, 'W',
                            32767);

        IF UTL_FILE.is_open (lt_output_file)
        THEN
            lv_line         :=
                   'OPERATING_UNIT'
                || lv_file_delimiter
                || 'VENDOR'
                || lv_file_delimiter
                || 'VENDOR_NUM'
                || lv_file_delimiter
                || 'VENDOR_SITE'
                || lv_file_delimiter
                || 'VENDOR_ADDRESS'
                || lv_file_delimiter
                || 'INVOICE_NUMBER'
                || lv_file_delimiter
                || 'INVOICE_DESCRIPTION'
                || lv_file_delimiter
                || 'INVOICE_SOURCE'
                || lv_file_delimiter
                || 'INVOICE_DATE'
                || lv_file_delimiter
                || 'ACCOUNTING_DATE'
                || lv_file_delimiter
                || 'GL_DATE'
                || lv_file_delimiter
                || 'INVOICE_DUE_DATE'
                || lv_file_delimiter
                || 'INVOICE_CREATION_DATE'
                || lv_file_delimiter
                || 'INVOICE_LAST_UPDATE_DATE'
                || lv_file_delimiter
                || 'INVOICE_LAST_UPDATE_BY'
                || lv_file_delimiter
                || 'INVOICE_CURRENCY'
                || lv_file_delimiter
                || 'INVOICE_TOTAL'
                || lv_file_delimiter
                || 'INVOICE_TOTAL_USD'
                || lv_file_delimiter
                || 'CONVERSION_RATE'
                || lv_file_delimiter
                || 'INVOICE_STATUS'
                || lv_file_delimiter
                || 'INVOICE_LINE_NUMBER'
                || lv_file_delimiter
                || 'INVOICE_LINE_SOURCE'
                || lv_file_delimiter
                || 'INVOICE_LINE_AMOUNT'
                || lv_file_delimiter
                || 'INVOICE_LINE_AMOUNT_USD'
                || lv_file_delimiter
                || 'PAYMENT_METHOD'
                || lv_file_delimiter
                || 'PAYMENT_STATUS_FLAG'
                || lv_file_delimiter
                || 'PAYMENT_STATUS'
                || lv_file_delimiter
                || 'REVERSAL_FLAG'
                || lv_file_delimiter
                || 'TERMS_DATE'
                || lv_file_delimiter
                || 'TERMS_NAME'
                || lv_file_delimiter
                || 'POSTED_FLAG'
                || lv_file_delimiter
                || 'DISTRIBUTION_DESCRIPTION'
                || lv_file_delimiter
                || 'DISTRIBUTION_LINE_NUMBER'
                || lv_file_delimiter
                || 'INVOICE_DISTRIBUTION_AMOUNT'
                || lv_file_delimiter
                || 'INVOICE_DISTRIBUTION_AMOUNT_USD'
                || lv_file_delimiter
                || 'AP_GL_COMPANY_CODE'
                || lv_file_delimiter
                || 'AP_GL_COMPANY_NAME'
                || lv_file_delimiter
                || 'AP_GL_BRAND_CODE'
                || lv_file_delimiter
                || 'AP_GL_BRAND_NAME'
                || lv_file_delimiter
                || 'AP_GL_GEO_CODE'
                || lv_file_delimiter
                || 'AP_GL_GEO_NAME'
                || lv_file_delimiter
                || 'AP_GL_CHANNEL_CODE'
                || lv_file_delimiter
                || 'AP_GL_CHANNEL_NAME'
                || lv_file_delimiter
                || 'AP_GL_COST_CENTER_CODE'
                || lv_file_delimiter
                || 'AP_GL_COST_CENTER_NAME'
                || lv_file_delimiter
                || 'AP_GL_NATURAL_ACCOUNT_CODE'
                || lv_file_delimiter
                || 'AP_GL_NATURAL_ACCOUNT_NAME'
                || lv_file_delimiter
                || 'REQUISITION_NUMBER'
                || lv_file_delimiter
                || 'PREPARER'
                || lv_file_delimiter
                || 'REQUESTER'
                || lv_file_delimiter
                || 'REQUESTER_EMAIL'
                || lv_file_delimiter
                || 'REQUISITION_APPROVER'
                || lv_file_delimiter
                || 'PO_NUMBER'
                || lv_file_delimiter
                || 'BUYER_NAME'
                || lv_file_delimiter
                || 'PO_STATUS'
                || lv_file_delimiter
                || 'PO_APPROVAL_STATUS'
                || lv_file_delimiter
                || 'PO_CREATION_DATE'
                || lv_file_delimiter
                || 'PO_APPROVAL_DATE'
                || lv_file_delimiter
                || 'SHIP_TO_ADDRESS'
                || lv_file_delimiter
                || 'BILL_TO_ADDRESS'
                || lv_file_delimiter
                || 'PO_LINE_NUMBER'
                || lv_file_delimiter
                || 'ITEM_DESCRIPTION'
                || lv_file_delimiter
                || 'ITEM_CATEGORY'
                || lv_file_delimiter
                || 'PO_CANCEL_FLAG'
                || lv_file_delimiter
                || 'PO_DISTRIBUTION_AMOUNT'
                || lv_file_delimiter
                || 'PO_DISTRIBUTION_AMOUNT_USD'
                || lv_file_delimiter
                || 'PO_GL_COMPANY_CODE'
                || lv_file_delimiter
                || 'PO_GL_COMPANY_NAME'
                || lv_file_delimiter
                || 'PO_GL_BRAND_CODE'
                || lv_file_delimiter
                || 'PO_GL_BRAND_NAME'
                || lv_file_delimiter
                || 'PO_GL_GEO_CODE'
                || lv_file_delimiter
                || 'PO_GL_GEO_NAME'
                || lv_file_delimiter
                || 'PO_GL_CHANNEL_CODE'
                || lv_file_delimiter
                || 'PO_GL_CHANNEL_NAME'
                || lv_file_delimiter
                || 'PO_GL_COST_CENTER_CODE'
                || lv_file_delimiter
                || 'PO_GL_COST_CENTER_NAME'
                || lv_file_delimiter
                || 'PO_GL_NATURAL_ACCOUNT_CODE'
                || lv_file_delimiter
                || 'PO_GL_NATURAL_ACCOUNT_NAME';
            insrt_msg ('OUTPUT', lv_line);
            UTL_FILE.put_line (lt_output_file, lv_line);
            insrt_msg ('OUTPUT', lv_line);
            lv_start_date   := fnd_date.canonical_to_date (p_inv_start_date);
            lv_end_date     := fnd_date.canonical_to_date (p_inv_end_date);

            OPEN report_cur (lv_start_date, lv_end_date);

            LOOP
                FETCH report_cur BULK COLLECT INTO v_rprt_type LIMIT ln_limit;

                insrt_msg (
                    'LOG',
                       'Start writing into file '
                    || v_rprt_type.COUNT
                    || ' records at '
                    || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'),
                    p_debug);
                ln_count   := ln_count + v_rprt_type.COUNT;

                IF (v_rprt_type.COUNT > 0)
                THEN
                    FOR i IN v_rprt_type.FIRST .. v_rprt_type.LAST
                    LOOP
                        lv_line   :=
                               v_rprt_type (i).operating_unit
                            || lv_file_delimiter
                            || get_trans_val (v_rprt_type (i).vendor)
                            || lv_file_delimiter
                            || v_rprt_type (i).vendor_num
                            || lv_file_delimiter
                            || get_trans_val (v_rprt_type (i).vendor_site)
                            || lv_file_delimiter
                            || get_trans_val (v_rprt_type (i).vendor_address)
                            || lv_file_delimiter
                            || get_trans_val (v_rprt_type (i).invoice_number)
                            || lv_file_delimiter
                            || get_trans_val (
                                   v_rprt_type (i).invoice_description)
                            || lv_file_delimiter
                            || v_rprt_type (i).invoice_source
                            || lv_file_delimiter
                            || v_rprt_type (i).invoice_date
                            || lv_file_delimiter
                            || v_rprt_type (i).accounting_date
                            || lv_file_delimiter
                            || v_rprt_type (i).gl_date
                            || lv_file_delimiter
                            || v_rprt_type (i).invoice_due_date
                            || lv_file_delimiter
                            || v_rprt_type (i).invoice_creation_date
                            || lv_file_delimiter
                            || v_rprt_type (i).invoice_last_update_date
                            || lv_file_delimiter
                            || v_rprt_type (i).invoice_last_update_by
                            || lv_file_delimiter
                            || v_rprt_type (i).invoice_currency
                            || lv_file_delimiter
                            || v_rprt_type (i).invoice_total
                            || lv_file_delimiter
                            || v_rprt_type (i).invoice_total_usd
                            || lv_file_delimiter
                            || v_rprt_type (i).conversion_rate
                            || lv_file_delimiter
                            || v_rprt_type (i).invoice_status
                            || lv_file_delimiter
                            || v_rprt_type (i).invoice_line_number
                            || lv_file_delimiter
                            || v_rprt_type (i).invoice_line_source
                            || lv_file_delimiter
                            || v_rprt_type (i).invoice_line_amount
                            || lv_file_delimiter
                            || v_rprt_type (i).invoice_line_amount_usd
                            || lv_file_delimiter
                            || v_rprt_type (i).payment_method
                            || lv_file_delimiter
                            || v_rprt_type (i).payment_status_flag
                            || lv_file_delimiter
                            || v_rprt_type (i).payment_status
                            || lv_file_delimiter
                            || v_rprt_type (i).reversal_flag
                            || lv_file_delimiter
                            || v_rprt_type (i).terms_date
                            || lv_file_delimiter
                            || get_trans_val (v_rprt_type (i).terms_name)
                            || lv_file_delimiter
                            || v_rprt_type (i).posted_flag
                            || lv_file_delimiter
                            || get_trans_val (
                                   v_rprt_type (i).distribution_description)
                            || lv_file_delimiter
                            || v_rprt_type (i).distribution_line_number
                            || lv_file_delimiter
                            || v_rprt_type (i).invoice_distribution_amount
                            || lv_file_delimiter
                            || v_rprt_type (i).invoice_distribution_amount_usd
                            || lv_file_delimiter
                            || v_rprt_type (i).ap_gl_company_code
                            || lv_file_delimiter
                            || get_trans_val (
                                   v_rprt_type (i).ap_gl_company_name)
                            || lv_file_delimiter
                            || v_rprt_type (i).ap_gl_brand_code
                            || lv_file_delimiter
                            || v_rprt_type (i).ap_gl_brand_name
                            || lv_file_delimiter
                            || v_rprt_type (i).ap_gl_geo_code
                            || lv_file_delimiter
                            || v_rprt_type (i).ap_gl_geo_name
                            || lv_file_delimiter
                            || v_rprt_type (i).ap_gl_channel_code
                            || lv_file_delimiter
                            || v_rprt_type (i).ap_gl_channel_name
                            || lv_file_delimiter
                            || v_rprt_type (i).ap_gl_cost_center_code
                            || lv_file_delimiter
                            || get_trans_val (
                                   v_rprt_type (i).ap_gl_cost_center_name)
                            || lv_file_delimiter
                            || v_rprt_type (i).ap_gl_natural_account_code
                            || lv_file_delimiter
                            || get_trans_val (
                                   v_rprt_type (i).ap_gl_natural_account_name)
                            || lv_file_delimiter
                            || v_rprt_type (i).requisition_number
                            || lv_file_delimiter
                            || get_trans_val (v_rprt_type (i).preparer)
                            || lv_file_delimiter
                            || get_trans_val (v_rprt_type (i).requester)
                            || lv_file_delimiter
                            || v_rprt_type (i).requester_email
                            || lv_file_delimiter
                            || get_trans_val (
                                   v_rprt_type (i).requisition_approver)
                            || lv_file_delimiter
                            || v_rprt_type (i).po_number
                            || lv_file_delimiter
                            || get_trans_val (v_rprt_type (i).buyer_name)
                            || lv_file_delimiter
                            || v_rprt_type (i).po_status
                            || lv_file_delimiter
                            || v_rprt_type (i).po_approval_status
                            || lv_file_delimiter
                            || v_rprt_type (i).po_creation_date
                            || lv_file_delimiter
                            || v_rprt_type (i).po_approval_date
                            || lv_file_delimiter
                            || get_trans_val (
                                   v_rprt_type (i).ship_to_address)
                            || lv_file_delimiter
                            || get_trans_val (
                                   v_rprt_type (i).bill_to_address)
                            || lv_file_delimiter
                            || v_rprt_type (i).po_line_number
                            || lv_file_delimiter
                            || get_trans_val (
                                   v_rprt_type (i).item_description)
                            || lv_file_delimiter
                            || get_trans_val (v_rprt_type (i).item_category)
                            || lv_file_delimiter
                            || v_rprt_type (i).po_cancel_flag
                            || lv_file_delimiter
                            || v_rprt_type (i).po_distribution_amount
                            || lv_file_delimiter
                            || v_rprt_type (i).po_distribution_amount_usd
                            || lv_file_delimiter
                            || v_rprt_type (i).po_gl_company_code
                            || lv_file_delimiter
                            || get_trans_val (
                                   v_rprt_type (i).po_gl_company_name)
                            || lv_file_delimiter
                            || v_rprt_type (i).po_gl_brand_code
                            || lv_file_delimiter
                            || v_rprt_type (i).po_gl_brand_name
                            || lv_file_delimiter
                            || v_rprt_type (i).po_gl_geo_code
                            || lv_file_delimiter
                            || v_rprt_type (i).po_gl_geo_name
                            || lv_file_delimiter
                            || v_rprt_type (i).po_gl_channel_code
                            || lv_file_delimiter
                            || v_rprt_type (i).po_gl_channel_name
                            || lv_file_delimiter
                            || v_rprt_type (i).po_gl_cost_center_code
                            || lv_file_delimiter
                            || get_trans_val (
                                   v_rprt_type (i).po_gl_cost_center_name)
                            || lv_file_delimiter
                            || v_rprt_type (i).po_gl_natural_account_code
                            || lv_file_delimiter
                            || get_trans_val (
                                   v_rprt_type (i).po_gl_natural_account_name);

                        UTL_FILE.put_line (lt_output_file, lv_line);
                    END LOOP;
                END IF;

                insrt_msg (
                    'LOG',
                       'End writing into file '
                    || v_rprt_type.COUNT
                    || ' records at '
                    || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'),
                    p_debug);
                v_rprt_type.delete;
                EXIT WHEN report_cur%NOTFOUND;
            END LOOP;

            CLOSE report_cur;

            UTL_FILE.fclose (lt_output_file);
            insrt_msg ('LOG', 'Total Records: ' || ln_count, 'Y');
        END IF;

        insrt_msg ('LOG', 'Completed generate_report Procedure', 'Y');
    EXCEPTION
        WHEN OTHERS
        THEN
            IF UTL_FILE.is_open (lt_output_file)
            THEN
                UTL_FILE.fclose (lt_output_file);
            END IF;

            insrt_msg ('LOG',
                       'Error while generating output: ' || SQLERRM,
                       'Y');
            x_ret_stat   := 1;
            x_msg        :=
                'Error while generating output. Please refer log file for more details';
    END generate_report;
END xxd_ap_nt_procure_ext_spnd_pkg;
/
