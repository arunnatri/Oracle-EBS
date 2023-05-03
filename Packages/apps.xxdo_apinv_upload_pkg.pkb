--
-- XXDO_APINV_UPLOAD_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:34:34 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_APINV_UPLOAD_PKG"
AS
    /***********************************************************************************
      *$header     :                                                                   *
      *                                                                                *
      * AUTHORS    :  Srinath Siricilla                                                *
      *                                                                                *
      * PURPOSE    :  AP Invoice Excel WEBADI Upload                                   *
      *                                                                                *
      * PARAMETERS :                                                                   *
      *                                                                                *
      * DATE       :  02-FEB-2017                                                      *
      *                                                                                *
      * Assumptions:                                                                   *
      *                                                                                *
      *                                                                                *
      * History                                                                        *
      * Vsn     Change Date  Changed By            Change Description                  *
      * -----   -----------  ------------------    ------------------------------------*
      * 1.0     02-FEB-2017  Srinath Siricilla     Initial Creation                    *
      * 1.1     14-JUN-2017  Srinath Siricilla     Adding fields to WEBADI Template    *
      *                                            ENHC0013263                         *
      * 1.2     26-JUN-2018  Srinath Siricilla     CCR0007341                          *
      * 1.3     08-MAY-2018  Tejaswi Gangumalla    CCR0008618                          *
      * 2.0     05-NOV-2020  Srinath Siricilla     CCR0008507 - MTD Changes            *
      *********************************************************************************/
    PROCEDURE clear_int_tables
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        --Delete Invoice Line rejections
        DELETE apps.ap_interface_rejections apr
         WHERE     parent_table = 'AP_INVOICE_LINES_INTERFACE'
               AND EXISTS
                       (SELECT 1
                          FROM apps.ap_invoice_lines_interface apl, apps.ap_invoices_interface api
                         WHERE     apl.invoice_line_id = apr.parent_id
                               AND api.invoice_id = apl.invoice_id
                               AND api.created_by = apps.fnd_global.user_id
                               --AND api.SOURCE = g_invoice_source
                               AND api.SOURCE IN ('LUCERNEX', 'EXCEL') -- Added as per CCR0008507
                                                                      );

        --Delete Invoice rejections
        DELETE apps.ap_interface_rejections apr
         WHERE     parent_table = 'AP_INVOICES_INTERFACE'
               AND EXISTS
                       (SELECT 1
                          FROM apps.ap_invoices_interface api
                         WHERE     api.invoice_id = apr.parent_id
                               AND api.created_by = apps.fnd_global.user_id --1037
                               --                            AND api.SOURCE = g_invoice_source
                               AND api.SOURCE IN ('LUCERNEX', 'EXCEL') -- Added as per CCR0008507
                                                                      );

        --Delete Invoice lines interface
        DELETE apps.ap_invoice_lines_interface lint
         WHERE EXISTS
                   (SELECT 1
                      FROM apps.ap_invoices_interface api
                     WHERE     api.invoice_id = lint.invoice_id
                           AND api.created_by = apps.fnd_global.user_id
                           --AND api.SOURCE = g_invoice_source
                           AND api.SOURCE IN ('LUCERNEX', 'EXCEL') -- Added as per CCR0008507
                                                                  );

        --Delete Invoices interface
        DELETE apps.ap_invoices_interface api
         WHERE     1 = 1
               AND api.created_by = apps.fnd_global.user_id
               --AND api.SOURCE = g_invoice_source
               AND api.SOURCE IN ('LUCERNEX', 'EXCEL') -- Added as per CCR0008507
                                                      ;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
    END clear_int_tables;

    FUNCTION is_org_valid (p_org_name   IN     VARCHAR2,
                           x_org_id        OUT NUMBER,
                           x_ret_msg       OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        l_org_id   NUMBER;
    BEGIN
        SELECT organization_id
          INTO x_org_id
          FROM apps.hr_operating_units
         WHERE     UPPER (NAME) = UPPER (TRIM (p_org_name))
               AND date_from <= SYSDATE
               AND NVL (date_to, SYSDATE) >= SYSDATE;

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   := ' Invalid Operating Unit Name.';
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   := ' Multiple Operating Units exist with same name.';
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   := ' ' || 'Invalid Operating Unit: ' || SQLERRM;
            RETURN FALSE;
    END is_org_valid;

    -- Added function for CCR0008507

    FUNCTION is_mtd_org (p_org_name       IN     VARCHAR2,
                         x_mtd_org_name      OUT VARCHAR2,
                         x_ret_msg           OUT VARCHAR2)
        RETURN BOOLEAN
    IS
    BEGIN
        SELECT ffvl.flex_value
          INTO x_mtd_org_name
          FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
         WHERE     1 = 1
               AND ffvs.flex_value_set_id = ffvl.flex_value_set_id
               AND ffvl.enabled_flag = 'Y'
               AND ffvs.flex_value_set_name = 'XXD_MTD_OU_VS'
               AND SYSDATE BETWEEN NVL (ffvl.start_date_active, SYSDATE - 1)
                               AND NVL (ffvl.end_date_active, SYSDATE + 1)
               AND UPPER (ffvl.flex_value) = UPPER (TRIM (p_org_name));

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   := ' Invalid MTD Operating Unit Name.';
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                ' Multiple MTD Operating Units exist with same name.';
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   := ' ' || 'Invalid MTD Operating Unit: ' || SQLERRM;
            RETURN FALSE;
    END is_mtd_org;

    -- End of Change

    FUNCTION is_vendor_valid (p_vendor_number IN VARCHAR2, x_vendor_id OUT NUMBER, x_vendor_name OUT VARCHAR2
                              , x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
    BEGIN
        SELECT vendor_id, vendor_name
          INTO x_vendor_id, x_vendor_name
          FROM apps.ap_suppliers
         WHERE     UPPER (TRIM (segment1)) = UPPER (TRIM (p_vendor_number))
               AND enabled_flag = 'Y';

        --AND NVL(attribute2,'N') = 'N'; -- GTN Supplier
        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   := ' Invalid Vendor. Supplier should be valid';
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   := ' Multiple Vendors exist with same name.';
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   := ' ' || 'Invalid Vendor: ' || SQLERRM;
            RETURN FALSE;
    END is_vendor_valid;

    FUNCTION is_site_valid (p_site_code IN VARCHAR2, p_org_id IN NUMBER, p_vendor_id IN NUMBER
                            , x_site_id OUT NUMBER, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
    BEGIN
        SELECT vendor_site_id
          INTO x_site_id
          FROM apps.ap_supplier_sites_all
         WHERE     UPPER (vendor_site_code) = UPPER (TRIM (p_site_code))
               AND org_id = p_org_id
               AND vendor_id = p_vendor_id;

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   := ' Invalid Vendor Site code.';
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   := ' Multiple Vendor Sites exist with same code.';
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   := ' ' || 'Invalid Vendor Site: ' || SQLERRM;
            RETURN FALSE;
    END is_site_valid;

    FUNCTION is_po_exists (p_po_num         IN     VARCHAR2,
                           p_vendor_id      IN     NUMBER,
                           p_org_id         IN     NUMBER,
                           x_po_header_id      OUT NUMBER,
                           x_ret_msg           OUT VARCHAR2)
        RETURN BOOLEAN
    IS
    BEGIN
        SELECT po_header_id
          INTO x_po_header_id
          FROM apps.po_headers_all
         WHERE     UPPER (segment1) = UPPER (TRIM (p_po_num))
               AND org_id = p_org_id
               AND vendor_id = p_vendor_id
               AND NVL (cancel_flag, 'N') = 'N'
               AND NVL (authorization_status, 'APPROVED') = 'APPROVED'
               AND NVL (closed_code, 'OPEN') = 'OPEN';

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   := ' Invalid PO Number';
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                ' Multiple PO exist with same Vendor and OU Combination';
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   := ' ' || 'Invalid PO: ' || SQLERRM;
            RETURN FALSE;
    END is_po_exists;

    FUNCTION is_po_line_exists (p_line_num     IN     NUMBER,
                                p_org_id       IN     NUMBER,
                                p_header_id    IN     NUMBER,
                                x_po_line_id      OUT NUMBER,
                                x_ret_msg         OUT VARCHAR2)
        RETURN BOOLEAN
    IS
    BEGIN
        SELECT po_line_id
          INTO x_po_line_id
          FROM apps.po_lines_all
         WHERE     line_num = TRIM (p_line_num)
               AND org_id = p_org_id
               AND po_header_id = p_header_id
               AND NVL (cancel_flag, 'N') = 'N'
               AND NVL (closed_code, 'OPEN') = 'OPEN';

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   := ' Invalid PO Line Number';
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                ' Multiple PO lines exist with same PO and Line combination';
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   := ' ' || 'Invalid PO Line Number: ' || SQLERRM;
            RETURN FALSE;
    END is_po_line_exists;

    FUNCTION is_curr_code_valid (p_curr_code   IN     VARCHAR2,
                                 x_ret_msg        OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        l_curr   NUMBER := 0;
    BEGIN
        SELECT 1
          INTO l_curr
          FROM apps.fnd_currencies
         WHERE     enabled_flag = 'Y'
               AND currency_code = UPPER (TRIM (p_curr_code));

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   := ' Invalid Currency Code.';
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   := ' Multiple Currencies exist with same code.';
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   := ' ' || 'Invalid Currency Code: ' || SQLERRM;
            RETURN FALSE;
    END is_curr_code_valid;

    FUNCTION is_flag_valid (p_flag      IN     VARCHAR2,
                            x_flag         OUT VARCHAR2,
                            x_ret_msg      OUT VARCHAR2)
        RETURN BOOLEAN
    IS
    BEGIN
        SELECT lookup_code
          INTO x_flag
          FROM apps.fnd_lookups
         WHERE     lookup_type = 'YES_NO'
               AND enabled_flag = 'Y'
               AND UPPER (meaning) = UPPER (TRIM (p_flag));

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   := ' Invalid - Value can be either Yes or No only;';
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   := ' Multiple Lookup values exist with same code;';
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   := ' ' || 'Invalid Lookup Code: ' || SQLERRM;
            RETURN FALSE;
    END is_flag_valid;

    FUNCTION get_curr_code (p_vendor_id        IN     NUMBER,
                            p_vendor_site_id   IN     NUMBER,
                            p_org_id           IN     NUMBER,
                            x_curr_code           OUT VARCHAR2,
                            x_ret_msg             OUT VARCHAR2)
        RETURN BOOLEAN
    IS
    BEGIN
        SELECT invoice_currency_code
          INTO x_curr_code
          FROM apps.ap_supplier_sites_all
         WHERE     vendor_site_id = p_vendor_site_id
               AND vendor_id = p_vendor_id
               AND org_id = p_org_id;

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   :=
                ' Please check the Currency Code at Supplier Site.';
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   := ' Multiple Currencies exist at the Supplier Site';
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   := ' ' || 'Invalid Currency Code: ' || SQLERRM;
            RETURN FALSE;
    END get_curr_code;

    FUNCTION is_inv_num_valid (p_inv_num IN VARCHAR2, p_vendor_id IN NUMBER, p_org_id IN NUMBER
                               , x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        l_count   NUMBER;
    BEGIN
        SELECT COUNT (1)
          INTO l_count
          FROM apps.ap_invoices_all
         WHERE     1 = 1
               AND org_id = p_org_id
               AND vendor_id = p_vendor_id
               AND UPPER (invoice_num) = TRIM (UPPER (p_inv_num));

        IF l_count > 0
        THEN
            x_ret_msg   :=
                ' Invoice number:' || p_inv_num || ' already exists.';
            RETURN FALSE;
        ELSE
            RETURN TRUE;
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            RETURN TRUE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                ' Invoice number:' || p_inv_num || ' already exists.';
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   :=
                   ' Unable to validate Invoice number:'
                || p_inv_num
                || ' - '
                || SQLERRM;
            RETURN FALSE;
    END is_inv_num_valid;

    FUNCTION is_pay_method_valid (p_pay_method IN VARCHAR2, x_code OUT VARCHAR2, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
    BEGIN
        SELECT lookup_code
          INTO x_code
          FROM apps.fnd_lookup_values
         WHERE     lookup_type = 'PAYMENT METHOD'
               AND LANGUAGE = USERENV ('LANG')
               AND enabled_flag = 'Y'
               AND UPPER (lookup_code) = UPPER (TRIM (p_pay_method));

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   := ' Invalid Payment method lookup code.';
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                ' Multiple payment method lookups exist with same name.';
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   := ' ' || 'Invalid Payment Method: ' || SQLERRM;
            RETURN FALSE;
    END is_pay_method_valid;

    FUNCTION get_pay_method (p_vendor_id        IN     NUMBER,
                             p_vendor_site_id   IN     NUMBER,
                             p_org_id           IN     NUMBER,
                             x_pay_method          OUT VARCHAR2,
                             x_ret_msg             OUT VARCHAR2)
        RETURN BOOLEAN
    IS
    BEGIN
        SELECT ieppm.payment_method_code
          INTO x_pay_method
          FROM apps.ap_supplier_sites_all assa, apps.ap_suppliers sup, apps.iby_external_payees_all iepa,
               apps.iby_ext_party_pmt_mthds ieppm
         WHERE     sup.vendor_id = assa.vendor_id
               AND assa.vendor_site_id = iepa.supplier_site_id
               AND iepa.ext_payee_id = ieppm.ext_pmt_party_id
               AND NVL (ieppm.inactive_date, SYSDATE + 1) > SYSDATE
               AND ieppm.primary_flag = 'Y'
               AND assa.pay_site_flag = 'Y'
               AND assa.vendor_site_id = p_vendor_site_id
               AND assa.org_id = p_org_id
               AND sup.vendor_id = p_vendor_id;

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            BEGIN
                SELECT ibeppm.payment_method_code
                  INTO x_pay_method
                  FROM ap_suppliers sup, iby_external_payees_all ibep, iby_ext_party_pmt_mthds ibeppm
                 WHERE     sup.party_id = ibep.payee_party_id
                       AND ibeppm.ext_pmt_party_id = ibep.ext_payee_id
                       AND ibep.supplier_site_id IS NULL
                       AND ibeppm.primary_flag = 'Y'
                       AND NVL (ibeppm.inactive_date, SYSDATE + 1) > SYSDATE
                       AND sup.vendor_id = p_vendor_id;

                RETURN TRUE;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    x_ret_msg   :=
                        ' Please check the Payment method code at Supplier';
                    RETURN FALSE;
                WHEN OTHERS
                THEN
                    x_ret_msg   :=
                           ' '
                        || 'Invalid Payment Method at Supplier: '
                        || SQLERRM;
                    RETURN FALSE;
            END;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                ' Multiple payment method codes exist with same name.';
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   := ' ' || 'Invalid Payment Method: ' || SQLERRM;
            RETURN FALSE;
    END get_pay_method;

    FUNCTION get_asset_book (p_asset_book IN VARCHAR2, x_asset_book OUT VARCHAR2, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        l_asset_book   VARCHAR2 (100);
    BEGIN
        SELECT book_type_code
          INTO l_asset_book
          FROM fa_book_controls
         WHERE UPPER (book_type_code) = UPPER (TRIM (p_asset_book));

        x_asset_book   := l_asset_book;
        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   := ' Invalid Book Type Code';
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   := ' Multiple book names exist with same name.';
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   := ' ' || 'Invalid Book Type: ' || SQLERRM;
            RETURN FALSE;
    END get_asset_book;

    FUNCTION is_asset_book_valid (p_asset_book IN VARCHAR2, p_org_id IN VARCHAR2, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        l_valid   VARCHAR2 (100);
    BEGIN
        SELECT DISTINCT fbc.book_type_code
          INTO l_valid
          FROM xle_le_ou_ledger_v xle, fa_book_controls_sec fbc
         WHERE     1 = 1
               AND fbc.set_of_books_id = xle.ledger_id
               AND UPPER (TRIM (fbc.book_type_code)) =
                   UPPER (TRIM (p_asset_book))
               AND xle.operating_unit_id = p_org_id;

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   := 'Invalid Asset book for the OU';
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                ' Multiple Asset Books exist with same name for OU.';
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   := ' ' || 'Invalid Book Type for OU: ' || SQLERRM;
            RETURN FALSE;
    END is_asset_book_valid;

    FUNCTION get_asset_category (p_asset_cat IN VARCHAR2, x_asset_cat_id OUT NUMBER, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        l_asset_cat_id   VARCHAR2 (100);
    BEGIN
        SELECT category_id
          INTO l_asset_cat_id
          FROM fa_categories
         WHERE    UPPER (TRIM (segment1))
               || '.'
               || UPPER (TRIM (segment2))
               || '.'
               || UPPER (TRIM (segment3)) =
               UPPER (TRIM (p_asset_cat));

        x_asset_cat_id   := l_asset_cat_id;
        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   := ' Invalid Asset Category';
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   := ' Multiple Asset categories exist with same name.';
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   := ' ' || 'Invalid Asset Category: ' || SQLERRM;
            RETURN FALSE;
    END get_asset_category;

    FUNCTION is_asset_cat_valid (p_asset_cat_id IN VARCHAR2, p_asset_book IN VARCHAR2, --x_valid_out     OUT VARCHAR2,
                                                                                       x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        l_valid   VARCHAR2 (100);
    BEGIN
        SELECT book_type_code
          INTO l_valid
          FROM apps.fa_category_books
         WHERE     UPPER (TRIM (book_type_code)) =
                   UPPER (TRIM (p_asset_book))
               AND category_id = p_asset_cat_id;

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   := ' Category doesnot belong to Asset Book';
        WHEN OTHERS
        THEN
            x_ret_msg   := ' ' || 'Invalid Asset and Category Exception. ';
    END;

    FUNCTION is_term_valid (p_terms     IN     VARCHAR2,
                            x_term_id      OUT NUMBER,
                            x_ret_msg      OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        l_term_id   NUMBER;
    BEGIN
        SELECT term_id
          INTO l_term_id
          FROM apps.ap_terms
         WHERE UPPER (TRIM (NAME)) = UPPER (TRIM (p_terms));

        x_term_id   := l_term_id;
        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   := ' Invalid Payment Term Name.';
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   := ' Multiple Payment terms exist with same name.';
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   := ' ' || 'Invalid Payment Term: ' || SQLERRM;
            RETURN FALSE;
    END is_term_valid;

    FUNCTION get_terms (p_vendor_id IN NUMBER, p_vendor_site_id IN NUMBER, p_org_id IN NUMBER
                        , x_term_id OUT NUMBER, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        l_term_id   NUMBER;
    BEGIN
        SELECT terms_id
          INTO l_term_id
          FROM apps.ap_supplier_sites_all
         WHERE     vendor_site_id = p_vendor_site_id
               AND vendor_id = p_vendor_id
               AND org_id = p_org_id;

        x_term_id   := l_term_id;
        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   :=
                ' Please check the Payment Terms at Supplier Site.';
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                ' Multiple Payment terms exist at the Supplier Site';
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   := ' ' || 'Invalid payment terms: ' || SQLERRM;
            RETURN FALSE;
    END get_terms;

    FUNCTION is_line_type_valid (p_line_type IN VARCHAR2, x_code OUT VARCHAR2, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        l_code   VARCHAR2 (30);
    BEGIN
        SELECT lookup_code
          INTO l_code
          FROM apps.fnd_lookup_values
         WHERE     lookup_type = 'INVOICE LINE TYPE'
               AND LANGUAGE = USERENV ('LANG')
               AND enabled_flag = 'Y'
               AND UPPER (TRIM (lookup_code)) = UPPER (TRIM (p_line_type));

        x_code   := l_code;
        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   := ' Invalid Line type lookup code.';
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                ' Multiple Line type lookup codes exist with same name.';
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   :=
                ' ' || 'Invalid Line type lookup code: ' || SQLERRM;
            RETURN FALSE;
    END is_line_type_valid;

    FUNCTION dist_account_exists (p_dist_acct IN VARCHAR2, x_dist_ccid OUT NUMBER, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
    BEGIN
        SELECT code_combination_id
          INTO x_dist_ccid
          FROM apps.gl_code_combinations_kfv
         WHERE     enabled_flag = 'Y'
               AND concatenated_segments = TRIM (p_dist_acct);

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   := ' Invalid Distribution Account.';
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                ' Multiple Accounts exist with same code combination.';
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   := ' ' || 'Invalid Distribution Account: ' || SQLERRM;
            RETURN FALSE;
    END dist_account_exists;

    FUNCTION is_interco_acct (p_interco_acct IN VARCHAR2, p_dist_ccid IN NUMBER, x_interco_acct_id OUT NUMBER
                              , x_ret_msg OUT NUMBER)
        RETURN BOOLEAN
    IS
    BEGIN
        SELECT gcc.code_combination_id
          INTO x_interco_acct_id
          FROM apps.gl_code_combinations_kfv gcc
         WHERE     gcc.detail_posting_allowed = 'Y'
               AND gcc.summary_flag = 'N'
               AND gcc.enabled_flag = 'Y'
               AND gcc.concatenated_segments = TRIM (p_interco_acct)
               AND gcc.segment1 IN
                       (SELECT SUBSTR (val.description, 1, 3)
                          FROM apps.fnd_flex_values_vl val, apps.fnd_flex_value_sets vset, apps.gl_code_combinations_kfv gcc1
                         WHERE     1 = 1
                               AND val.flex_value_set_id =
                                   vset.flex_value_set_id
                               AND val.enabled_flag = 'Y'
                               AND vset.flex_value_set_name =
                                   'XXDO_INTERCO_AP_AR_MAPPING'
                               AND val.flex_value =
                                   gcc1.concatenated_segments
                               AND gcc1.code_combination_id = p_dist_ccid)
               AND gcc.segment6 NOT IN
                       (SELECT val1.flex_value
                          FROM apps.fnd_flex_values_vl val1, apps.fnd_flex_value_sets vset1
                         WHERE     1 = 1
                               AND val1.flex_value_set_id =
                                   vset1.flex_value_set_id
                               AND val1.enabled_flag = 'Y'
                               AND vset1.flex_value_set_name =
                                   'XXDO_INTERCO_RESTRICTIONS');

        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_msg   := ' Invalid Interco Account: ' || SQLERRM;
            RETURN FALSE;
    END is_interco_acct;

    FUNCTION dist_set_exists (p_dist_set_name IN VARCHAR2, p_org_id IN NUMBER, x_dist_id OUT NUMBER
                              , x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        l_set_id   NUMBER;
    BEGIN
        SELECT distribution_set_id
          INTO l_set_id
          FROM apps.ap_distribution_sets_all
         WHERE     1 = 1
               AND UPPER (TRIM (distribution_set_name)) =
                   UPPER (TRIM (p_dist_set_name))
               AND org_id = p_org_id;

        x_dist_id   := l_set_id;
        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   := ' Invalid Distribtuion set name.';
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                ' Multiple Distribtuion sets exist with same name.';
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   := ' Invalid Distribution Set: ' || SQLERRM;
            RETURN FALSE;
    END dist_set_exists;

    FUNCTION is_ship_to_valid (p_ship_to_code IN VARCHAR2, x_ship_to_loc_id OUT NUMBER, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        l_location_id   NUMBER;
    BEGIN
        SELECT location_id
          INTO l_location_id
          FROM apps.hr_locations_all
         WHERE     1 = 1
               AND UPPER (TRIM (location_code)) =
                   UPPER (TRIM (p_ship_to_code));

        x_ship_to_loc_id   := l_location_id;
        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   :=
                ' Invalid Ship to location code:' || p_ship_to_code;
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                   ' Multiple Ship to location codes exist with same name:'
                || p_ship_to_code;
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   :=
                   ' Invalid Ship to location code:'
                || p_ship_to_code
                || '  '
                || SQLERRM;
            RETURN FALSE;
    END is_ship_to_valid;

    FUNCTION is_gl_date_valid (p_gl_date IN DATE, p_org_id IN NUMBER, p_param_value IN VARCHAR2 --Added for change1.3
                               , x_ret_msg OUT VARCHAR2)
        RETURN DATE
    IS
        l_valid_date   DATE;
    BEGIN
        --Commented below code for change 1.3
        /* IF p_gl_date IS NOT NULL THEN
            SELECT p_gl_date
              INTO l_valid_date
              FROM apps.gl_period_statuses gps
                 , apps.hr_operating_units hou
             WHERE gps.application_id = 200 --SQLAP
               AND gps.ledger_id = hou.set_of_books_id
               AND hou.organization_id = p_org_id
               AND gps.start_date <= p_gl_date
               AND gps.end_date >= p_gl_date
               AND gps.closing_status = 'O';
         ELSE
            SELECT MAX(gps.start_date)
              INTO l_valid_date
              FROM apps.gl_period_statuses gps
                 , apps.hr_operating_units hou
             WHERE gps.application_id = 200 --SQLAP
               AND gps.ledger_id = hou.set_of_books_id
               AND hou.organization_id = p_org_id
               AND gps.closing_status = 'O';
         END IF;
         RETURN l_valid_date;*/
        --Added below code for change 1.3
        IF p_gl_date IS NOT NULL AND p_param_value = 'Y'
        THEN
            BEGIN
                SELECT p_gl_date
                  INTO l_valid_date
                  FROM apps.gl_period_statuses gps, apps.hr_operating_units hou
                 WHERE     gps.application_id = 200                    --SQLAP
                       AND gps.ledger_id = hou.set_of_books_id
                       AND hou.organization_id = p_org_id
                       AND gps.start_date <= p_gl_date
                       AND gps.end_date >= p_gl_date
                       AND gps.closing_status IN ('O', 'F');
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    x_ret_msg   :=
                        ' GL Date is not in open AP Period:' || p_gl_date;
                    RETURN NULL;
                WHEN OTHERS
                THEN
                    x_ret_msg   :=
                        ' Invalid GL Date:' || p_gl_date || SQLERRM;
                    RETURN NULL;
            END;
        ELSIF p_gl_date IS NOT NULL AND p_param_value = 'N'
        THEN
            BEGIN
                SELECT p_gl_date
                  INTO l_valid_date
                  FROM apps.gl_period_statuses gps, apps.hr_operating_units hou
                 WHERE     gps.application_id = 200                    --SQLAP
                       AND gps.ledger_id = hou.set_of_books_id
                       AND hou.organization_id = p_org_id
                       AND gps.start_date <= p_gl_date
                       AND gps.end_date >= p_gl_date
                       AND gps.closing_status IN ('O', 'F');
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    l_valid_date   := NULL;
                WHEN OTHERS
                THEN
                    x_ret_msg      :=
                        ' Invalid GL Date:' || p_gl_date || SQLERRM;
                    l_valid_date   := NULL;
                    RETURN l_valid_date;
            END;

            IF l_valid_date IS NULL
            THEN
                BEGIN
                    SELECT MIN (gps.start_date)
                      INTO l_valid_date
                      FROM apps.gl_period_statuses gps, apps.hr_operating_units hou
                     WHERE     gps.application_id = 200                --SQLAP
                           AND gps.ledger_id = hou.set_of_books_id
                           AND hou.organization_id = p_org_id
                           AND gps.closing_status = 'O';
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        x_ret_msg   :=
                            ' GL Date is not in open AP Period:' || p_gl_date;
                        RETURN NULL;
                    WHEN OTHERS
                    THEN
                        x_ret_msg   :=
                            ' Invalid GL Date:' || p_gl_date || SQLERRM;
                        RETURN NULL;
                END;
            END IF;
        END IF;

        RETURN l_valid_date;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   := ' GL Date is not in open AP Period:' || p_gl_date;
            RETURN NULL;
        WHEN OTHERS
        THEN
            x_ret_msg   := ' Invalid GL Date:' || p_gl_date || SQLERRM;
            RETURN NULL;
    END is_gl_date_valid;

    FUNCTION validate_amount (p_amount    IN     VARCHAR2,
                              x_amount       OUT NUMBER,
                              x_ret_msg      OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        l_amount   NUMBER;
    BEGIN
        SELECT TO_NUMBER (p_amount) INTO x_amount FROM DUAL;

        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_msg   := 'Invalid Number format';
            RETURN FALSE;
    END validate_amount;

    FUNCTION is_tax_code_valid (p_tax_code IN VARCHAR2, x_tax_code OUT VARCHAR2, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
    BEGIN
        SELECT lookup_code
          INTO x_tax_code
          FROM apps.fnd_lookup_values
         WHERE     lookup_type = 'ZX_OUTPUT_CLASSIFICATIONS'
               AND LANGUAGE = USERENV ('LANG')
               AND UPPER (TRIM (lookup_code)) = UPPER (TRIM (p_tax_code));

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   := ' Invalid Tax Classification code:' || p_tax_code;
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                   ' Multiple Tax Classification codes exist with same name: '
                || p_tax_code;
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   :=
                   ' Invalid Tax Classification code: '
                || p_tax_code
                || '  '
                || SQLERRM;
            RETURN FALSE;
    END is_tax_code_valid;

    -- Added below function for change 1.3
    FUNCTION is_pay_group_valid (p_pay_group IN VARCHAR2, x_code OUT VARCHAR2, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
    BEGIN
        SELECT lookup_code
          INTO x_code
          FROM apps.fnd_lookup_values
         WHERE     lookup_type = 'PAY GROUP'
               AND LANGUAGE = USERENV ('LANG')
               AND NVL (enabled_flag, 'Y') = 'Y'
               AND SYSDATE BETWEEN NVL (start_date_active, SYSDATE)
                               AND NVL (end_date_active, SYSDATE)
               AND UPPER (lookup_code) = UPPER (TRIM (p_pay_group));

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_msg   := ' Invalid Pay group lookup code = ' || p_pay_group;
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_ret_msg   :=
                   ' Multiple pay group codes exist with same name = '
                || p_pay_group;
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_ret_msg   := ' ' || 'Invalid Pay group: ' || SQLERRM;
            RETURN FALSE;
    END is_pay_group_valid;

    FUNCTION get_invoice_source (p_inv_source IN VARCHAR2, x_source OUT VARCHAR2, x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
    BEGIN
        x_source   := NULL;

        SELECT lookup_code
          INTO x_source
          FROM apps.fnd_lookup_values_vl
         WHERE     enabled_flag = 'Y'
               AND lookup_type = 'SOURCE'
               AND SYSDATE BETWEEN NVL (start_date_active, SYSDATE - 1)
                               AND NVL (end_date_active, SYSDATE + 1)
               AND UPPER (lookup_code) = UPPER (TRIM (p_inv_source))
               AND lookup_code IN ('EXCEL', 'LUCERNEX');

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_source    := NULL;
            x_ret_msg   := ' Invalid Source  = ' || p_inv_source;
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            x_source   := NULL;
            x_ret_msg   :=
                ' Multiple sources exist with same name = ' || p_inv_source;
            RETURN FALSE;
        WHEN OTHERS
        THEN
            x_source    := NULL;
            x_ret_msg   := ' ' || 'Invalid Source: ' || SQLERRM;
            RETURN FALSE;
    END get_invoice_source;

    FUNCTION get_email (x_ret_msg OUT VARCHAR2)
        RETURN VARCHAR2
    IS
        l_emp_id   NUMBER;
        l_email    VARCHAR2 (240);
    BEGIN
        BEGIN
            SELECT employee_id, email_address
              INTO l_emp_id, l_email
              FROM apps.fnd_user
             WHERE user_id = apps.fnd_global.user_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END;

        IF l_email IS NULL AND l_emp_id IS NOT NULL
        THEN
            BEGIN
                SELECT ppf.email_address
                  INTO l_email
                  FROM apps.per_all_people_f ppf
                 WHERE ppf.person_id = l_emp_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_ret_msg   := 'Unable to get email address.';
                    RETURN NULL;
            END;

            RETURN l_email;
        ELSIF l_emp_id IS NULL AND l_email IS NULL
        THEN
            x_ret_msg   := 'Unable to get email address.';
            RETURN NULL;
        ELSIF l_email IS NOT NULL
        THEN
            RETURN l_email;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_msg   := 'Unable to get email address.';
            RETURN NULL;
    END get_email;

    FUNCTION is_invoice_created (p_org_id           IN     NUMBER,
                                 p_invoice_num      IN     VARCHAR2,
                                 p_vendor_id        IN     NUMBER,
                                 p_vendor_site_id   IN     NUMBER,
                                 x_invoice_id          OUT NUMBER)
        RETURN BOOLEAN
    IS
        l_invoice_id   NUMBER := 0;
    BEGIN
        SELECT invoice_id
          INTO l_invoice_id
          FROM apps.ap_invoices_all
         WHERE     1 = 1
               AND invoice_num = p_invoice_num
               AND org_id = p_org_id
               AND vendor_id = p_vendor_id
               AND vendor_site_id = p_vendor_site_id;

        x_invoice_id   := l_invoice_id;
        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_invoice_id   := NULL;
            RETURN FALSE;
    END is_invoice_created;

    FUNCTION is_line_created (p_invoice_id    IN NUMBER,
                              p_line_number   IN NUMBER)
        RETURN BOOLEAN
    IS
        l_count   NUMBER := 0;
    BEGIN
        SELECT COUNT (1)
          INTO l_count
          FROM apps.ap_invoice_lines_all
         WHERE invoice_id = p_invoice_id AND line_number = p_line_number;

        IF l_count = 1
        THEN
            RETURN TRUE;
        ELSE
            RETURN FALSE;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN FALSE;
    END is_line_created;

    FUNCTION get_error_desc (p_rejection_code IN VARCHAR2)
        RETURN VARCHAR2
    IS
        l_desc   VARCHAR2 (240);
    BEGIN
        SELECT description
          INTO l_desc
          FROM apps.fnd_lookup_values
         WHERE     lookup_code = p_rejection_code
               AND lookup_type = 'REJECT CODE'
               AND LANGUAGE = USERENV ('LANG');

        RETURN l_desc;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_error_desc;

    PROCEDURE load_interface (x_ret_code   OUT VARCHAR2,
                              x_ret_msg    OUT VARCHAR2)
    IS
        CURSOR c_valid_hdr IS
            SELECT invoice_number, operating_unit, vendor_name,
                   vendor_number, vendor_site_code, invoice_date,
                   invoice_amount, hdr_description, user_entered_tax,
                   tax_control_amt, fapio_received, invoice_currency_code,
                   payment_method, payment_terms, approver,
                   date_sent_approver, misc_notes, payment_ref,
                   chargeback, invoice_number_d, sample_invoice,
                   org_id, vendor_id, vendor_site_id,
                   payment_code, fapio_flag, sample_inv_flag,
                   invoice_type_lookup_code, process_flag, error_message,
                   created_by, creation_date, po_number,
                   last_updated_by, last_update_date, gl_date,
                   temp_invoice_hdr_id, unique_seq, po_header_id,
                   pay_alone, pay_alone_flag, inv_addl_info,
                   pay_group, source,               -- Added as per CCR0008507
                                      mtd_ou_flag   -- Added as per CCR0008507
              FROM xxdo.xxd_ap_inv_upload_hdrs
             WHERE     1 = 1
                   AND process_flag = g_validated
                   AND request_id = gn_conc_request_id; --Added for change 1.3

        --AND unique_seq = g_unique_seq;

        CURSOR c_valid_line (p_invoice_id IN NUMBER)
        IS
              SELECT line_number, line_type, line_description,
                     ship_to_location_code, line_amount, distribution_account,
                     dist_account_ccid, ship_to_location_id, unit_price,
                     temp_invoice_hdr_id, distribution_set, distribution_set_id,
                     process_flag, error_message, created_by,
                     creation_date, last_updated_by, last_update_date,
                     interco_exp_account, interco_exp_account_id, temp_invoice_line_id,
                     po_line_id, po_header_l_id, tax_classification_code,
                     asset_book, asset_book_code, asset_category,
                     asset_cat_id, track_as_asset, asset_flag,
                     deferred_flag, deferred_start_date, deferred_end_date,
                     prorate_flag
                FROM xxdo.xxd_ap_inv_upload_lines
               WHERE 1 = 1 AND temp_invoice_hdr_id = p_invoice_id
            ORDER BY line_number;

        l_valid_hdr_count     NUMBER := 0;
        l_valid_lin_count     NUMBER := 0;
        ex_no_valid_data      EXCEPTION;
        l_count               NUMBER := 0;
        header_seq            NUMBER;
        line_seq              NUMBER;
        lc_err_msg            VARCHAR2 (4000);
        lc_line_err_msg       VARCHAR2 (4000);
        le_webadi_exception   EXCEPTION;
    BEGIN
        SELECT COUNT (1)
          INTO l_count
          FROM xxdo.xxd_ap_inv_upload_hdrs
         WHERE process_flag = g_validated AND request_id = gn_conc_request_id; --Added for change 1.3

        --AND unique_seq = g_unique_seq;

        IF l_count > 0
        THEN
            FOR r_valid_hdr IN c_valid_hdr
            LOOP
                BEGIN
                    lc_err_msg   := NULL;

                    INSERT INTO apps.ap_invoices_interface (
                                    invoice_id,
                                    invoice_num,
                                    vendor_id,
                                    vendor_site_id,
                                    invoice_amount,
                                    description,
                                    -- Added on 14-JUN-2017 for ENHC0013263
                                    SOURCE,
                                    org_id,
                                    payment_method_code,
                                    terms_id,
                                    po_number,
                                    invoice_type_lookup_code,
                                    gl_date,
                                    invoice_date,
                                    invoice_currency_code,
                                    exchange_date,
                                    created_by,
                                    creation_date,
                                    last_updated_by,
                                    last_update_date,
                                    control_amount,
                                    exclusive_payment_flag,
                                    attribute_category,
                                    attribute1,
                                    attribute2,
                                    attribute3,
                                    attribute4,
                                    attribute5,
                                    attribute6,
                                    attribute7,
                                    attribute8,
                                    attribute10,
                                    attribute11,
                                    pay_group_lookup_code, --Added for change 1.3
                                    calc_tax_during_import_flag -- Added as per CCR0008507
                                                               )
                             VALUES (
                                        r_valid_hdr.temp_invoice_hdr_id,
                                        r_valid_hdr.invoice_number,
                                        r_valid_hdr.vendor_id,
                                        r_valid_hdr.vendor_site_id,
                                        r_valid_hdr.invoice_amount,
                                        r_valid_hdr.hdr_description,
                                        -- Added on 14-JUN-2017 for ENHC0013263
                                        r_valid_hdr.source, --g_invoice_source,-- Added as per CCR0008507
                                        --'COMMISSIONS',
                                        r_valid_hdr.org_id,
                                        r_valid_hdr.payment_method,
                                        r_valid_hdr.payment_terms,
                                        r_valid_hdr.po_number,
                                        r_valid_hdr.invoice_type_lookup_code,
                                        --'STANDARD',
                                        r_valid_hdr.gl_date,
                                        r_valid_hdr.invoice_date,
                                        r_valid_hdr.invoice_currency_code,
                                        r_valid_hdr.gl_date,
                                        r_valid_hdr.created_by,
                                        r_valid_hdr.creation_date,
                                        r_valid_hdr.last_updated_by,
                                        r_valid_hdr.last_update_date,
                                        r_valid_hdr.tax_control_amt,
                                        r_valid_hdr.pay_alone_flag,
                                        'Invoice Global Data Elements',
                                        r_valid_hdr.user_entered_tax,
                                        r_valid_hdr.date_sent_approver,
                                        r_valid_hdr.misc_notes,
                                        r_valid_hdr.approver,
                                        r_valid_hdr.chargeback,
                                        r_valid_hdr.invoice_number_d,
                                        r_valid_hdr.payment_ref,
                                        r_valid_hdr.sample_inv_flag,
                                        r_valid_hdr.fapio_flag,
                                        r_valid_hdr.inv_addl_info,
                                        r_valid_hdr.pay_group, --Added for change 1.3
                                        DECODE (r_valid_hdr.mtd_ou_flag,
                                                'Y', 'Y') -- Added as per CCR0008507
                                                         );

                    --COMMIT;
                    UPDATE xxdo.xxd_ap_inv_upload_hdrs
                       SET process_flag   = g_interfaced
                     WHERE temp_invoice_hdr_id =
                           r_valid_hdr.temp_invoice_hdr_id;

                    FOR r_valid_line
                        IN c_valid_line (r_valid_hdr.temp_invoice_hdr_id)
                    LOOP
                        BEGIN
                            lc_line_err_msg   := NULL;

                            INSERT INTO apps.ap_invoice_lines_interface (
                                            invoice_id,
                                            invoice_line_id,
                                            line_number,
                                            line_type_lookup_code,
                                            amount,
                                            accounting_date,
                                            dist_code_combination_id,
                                            distribution_set_id,
                                            ship_to_location_id,
                                            description,
                                            created_by,
                                            creation_date,
                                            last_updated_by,
                                            last_update_date,
                                            attribute_category,
                                            attribute2,
                                            po_header_id,
                                            po_line_id,
                                            po_shipment_num,
                                            asset_book_type_code,
                                            asset_category_id,
                                            assets_tracking_flag,
                                            prorate_across_flag,
                                            deferred_acctg_flag,
                                            def_acctg_start_date,
                                            def_acctg_end_date,
                                            tax_classification_code)
                                     VALUES (
                                                r_valid_hdr.temp_invoice_hdr_id,
                                                --invoice_id
                                                r_valid_line.temp_invoice_line_id,
                                                r_valid_line.line_number,
                                                r_valid_line.line_type,
                                                --'ITEM',   --line type lookup code
                                                r_valid_line.line_amount,
                                                r_valid_hdr.gl_date,
                                                r_valid_line.dist_account_ccid,
                                                r_valid_line.distribution_set_id,
                                                r_valid_line.ship_to_location_id,
                                                r_valid_line.line_description,
                                                r_valid_line.created_by,
                                                r_valid_line.creation_date,
                                                r_valid_line.last_updated_by,
                                                r_valid_line.last_update_date,
                                                'Invoice Lines Data Elements',
                                                r_valid_line.interco_exp_account_id,
                                                r_valid_line.po_header_l_id,
                                                r_valid_line.po_line_id,
                                                1,
                                                r_valid_line.asset_book_code,
                                                r_valid_line.asset_cat_id,
                                                r_valid_line.asset_flag,
                                                r_valid_line.prorate_flag,
                                                r_valid_line.deferred_flag,
                                                r_valid_line.deferred_start_date,
                                                r_valid_line.deferred_end_date,
                                                r_valid_line.tax_classification_code);

                            UPDATE xxdo.xxd_ap_inv_upload_lines
                               SET process_flag   = g_interfaced
                             WHERE temp_invoice_line_id =
                                   r_valid_line.temp_invoice_line_id;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lc_line_err_msg   := SUBSTR (SQLERRM, 1, 200);

                                UPDATE xxdo.xxd_ap_inv_upload_lines
                                   SET process_flag = g_errored, error_message = lc_line_err_msg
                                 WHERE temp_invoice_line_id =
                                       r_valid_hdr.temp_invoice_hdr_id;
                        END;
                    END LOOP;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lc_err_msg   := SUBSTR (SQLERRM, 1, 200);

                        UPDATE xxdo.xxd_ap_inv_upload_hdrs
                           SET process_flag = g_errored, error_message = lc_err_msg
                         WHERE temp_invoice_hdr_id =
                               r_valid_hdr.temp_invoice_hdr_id;
                END;
            END LOOP;
        ELSE
            NULL;
        END IF;

        COMMIT;
    EXCEPTION
        WHEN ex_no_valid_data
        THEN
            lc_err_msg   := ' No valid data for creation of invoices.';

            UPDATE xxdo.xxd_ap_inv_upload_hdrs
               SET process_flag = g_errored, error_message = error_message || '-' || lc_err_msg
             WHERE 1 = 1 AND request_id = gn_conc_request_id; --Added for change 1.3
        --AND unique_seq = g_unique_seq;
        WHEN OTHERS
        THEN
            lc_err_msg   :=
                'Others Exception occurred ' || SUBSTR (SQLERRM, 1, 200);

            UPDATE xxdo.xxd_ap_inv_upload_hdrs
               SET process_flag = g_errored, error_message = error_message || '-' || lc_err_msg
             WHERE 1 = 1 AND request_id = gn_conc_request_id; --Added for change 1.3

            --AND unique_seq = g_unique_seq;

            COMMIT;
    END load_interface;

    PROCEDURE create_invoices (x_ret_code   OUT VARCHAR2,
                               x_ret_msg    OUT VARCHAR2)
    IS
        l_request_id       NUMBER;
        l_req_boolean      BOOLEAN;
        l_req_phase        VARCHAR2 (30);
        l_req_status       VARCHAR2 (30);
        l_req_dev_phase    VARCHAR2 (30);
        l_req_dev_status   VARCHAR2 (30);
        l_req_message      VARCHAR2 (4000);
        l_invoice_count    NUMBER := 0;
        l_inv_source       VARCHAR2 (100);
        ex_no_invoices     EXCEPTION;

        CURSOR INV_CUR IS
              SELECT COUNT (1) inv_count, source inv_source -- Added as per CCR0008507
                --INTO l_invoice_count,l_inv_source -- Added as per CCR0008507
                FROM apps.ap_invoices_interface
               WHERE     NVL (status, 'XXX') NOT IN ('PROCESSED', 'REJECTED')
                     AND created_by = apps.fnd_global.user_id
                     --             AND SOURCE = g_invoice_source;
                     AND SOURCE IN ('LUCERNEX', 'EXCEL')
            GROUP BY SOURCE;
    BEGIN
        --Check if invoices exist for processing
        --      SELECT COUNT (1),source -- Added as per CCR0008507
        --        INTO l_invoice_count,l_inv_source -- Added as per CCR0008507
        --        FROM apps.ap_invoices_interface
        --       WHERE     NVL (status, 'XXX') NOT IN ('PROCESSED', 'REJECTED')
        --             AND created_by = apps.fnd_global.user_id
        ----             AND SOURCE = g_invoice_source;
        --             AND SOURCE IN ('LUCERNEX','EXCEL');

        FOR i IN INV_CUR
        LOOP
            l_request_id       := NULL;             -- Added as per CCR0008507
            l_req_phase        := NULL;
            l_req_status       := NULL;
            l_req_dev_phase    := NULL;
            l_req_dev_status   := NULL;
            l_req_message      := NULL;
            l_req_boolean      := NULL;

            IF i.inv_count > 0
            THEN
                --   RAISE ex_no_invoices;
                --END IF;
                apps.mo_global.set_policy_context ('S',
                                                   apps.fnd_global.org_id);
                apps.mo_global.init ('SQLAP');
                l_request_id   :=
                    apps.fnd_request.submit_request (
                        application   => 'SQLAP',
                        program       => 'APXIIMPT',
                        description   => '',
                        --'Payables Open Interface Import'
                        start_time    => SYSDATE,                     --,NULL,
                        sub_request   => FALSE,
                        argument1     => apps.fnd_global.org_id,
                        --2 org_id
                        argument2     => i.inv_source, --g_invoice_source,-- -- Added as per CCR0008507
                        --'COMMISSIONS',  --p_source
                        argument3     => '',
                        argument4     => 'N/A',
                        argument5     => '',
                        argument6     => '',
                        argument7     =>
                            TO_CHAR (SYSDATE, 'YYYY/MM/DD HH24:MI:SS'),
                        argument8     => 'N',                  --'N', -- purge
                        argument9     => 'N',           --'N', -- trace_switch
                        argument10    => 'N',           --'N', -- debug_switch
                        argument11    => 'N',
                        --'N', -- summarize report
                        argument12    => 1000,
                        --1000, -- commit_batch_size
                        argument13    => apps.fnd_global.user_id,
                        --'1037',
                        argument14    => apps.fnd_global.login_id --'1347386776'
                                                                 );

                IF l_request_id <> 0
                THEN
                    COMMIT;
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                        'AP Request ID= ' || l_request_id);
                ELSIF l_request_id = 0
                THEN
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                           'Request Not Submitted due to "'
                        || apps.fnd_message.get
                        || '".');
                END IF;

                --===IF successful RETURN ar customer trx id as OUT parameter;
                IF l_request_id > 0
                THEN
                    LOOP
                        l_req_boolean   :=
                            apps.fnd_concurrent.wait_for_request (
                                l_request_id,
                                15,
                                0,
                                l_req_phase,
                                l_req_status,
                                l_req_dev_phase,
                                l_req_dev_status,
                                l_req_message);
                        EXIT WHEN    UPPER (l_req_phase) = 'COMPLETED'
                                  OR UPPER (l_req_status) IN
                                         ('CANCELLED', 'ERROR', 'TERMINATED');
                    END LOOP;

                    IF     UPPER (l_req_phase) = 'COMPLETED'
                       AND UPPER (l_req_status) = 'ERROR'
                    THEN
                        apps.fnd_file.put_line (
                            apps.fnd_file.LOG,
                               'The Payables Open Import prog completed in error. See log for request id:'
                            || l_request_id);
                        apps.fnd_file.put_line (apps.fnd_file.LOG, SQLERRM);
                        x_ret_code   := '2';
                        x_ret_msg    :=
                               'The Payables Open Import request failed.Review log for Oracle request id '
                            || l_request_id;
                    ELSIF     UPPER (l_req_phase) = 'COMPLETED'
                          AND UPPER (l_req_status) = 'NORMAL'
                    THEN
                        apps.fnd_file.put_line (
                            apps.fnd_file.LOG,
                               'The Payables Open Import request id: '
                            || l_request_id);
                    ELSE
                        apps.fnd_file.put_line (
                            apps.fnd_file.LOG,
                               'The Payables Open Import request failed.Review log for Oracle request id '
                            || l_request_id);
                        apps.fnd_file.put_line (apps.fnd_file.LOG, SQLERRM);
                        x_ret_code   := '2';
                        x_ret_msg    :=
                               'The Payables Open Import request failed.Review log for Oracle request id '
                            || l_request_id;
                    END IF;
                END IF;
            ELSE
                NULL;
            END IF;
        END LOOP;
    EXCEPTION
        WHEN ex_no_invoices
        THEN
            x_ret_msg    :=
                   x_ret_msg
                || ' No invoice data available for invoice creation.';
            x_ret_code   := '2';
            apps.fnd_file.put_line (apps.fnd_file.LOG, x_ret_msg);
        WHEN OTHERS
        THEN
            x_ret_msg    :=
                x_ret_msg || ' Error in create_invoices:' || SQLERRM;
            x_ret_code   := '2';
            apps.fnd_file.put_line (apps.fnd_file.LOG, x_ret_msg);
    END create_invoices;

    PROCEDURE xxdo_apinv_stgload_prc (
        p_po_number                 IN VARCHAR2,
        p_invoice_num               IN VARCHAR2,
        p_operating_unit            IN VARCHAR2,
        p_vendor_name               IN VARCHAR2,
        p_vendor_number             IN VARCHAR2,
        p_vednor_site_code          IN VARCHAR2,
        p_invoice_date              IN DATE,
        p_inv_amount                IN NUMBER,
        p_user_entered_tax          IN VARCHAR2,
        p_tax_control_amt           IN NUMBER,
        p_fapio_received            IN VARCHAR2,
        p_line_type                 IN VARCHAR2,
        p_description               IN VARCHAR2,
        p_line_amount               IN NUMBER,
        p_dist_account              IN VARCHAR2,
        p_ship_to_location          IN VARCHAR2,
        p_po_number_l               IN VARCHAR2,
        p_po_line_num               IN NUMBER,
        p_qty_invoiced              IN NUMBER,
        p_unit_price                IN NUMBER,
        p_tax_classification_code   IN VARCHAR2,
        p_interco_exp_account       IN VARCHAR2,
        p_deferred                  IN VARCHAR2,
        p_deferred_start_date       IN DATE,
        p_deferred_end_date         IN DATE,
        p_prorate                   IN VARCHAR2,
        p_track_as_asset            IN VARCHAR2,
        p_asset_category            IN VARCHAR2,
        p_currency_code             IN VARCHAR2,
        p_pay_method                IN VARCHAR2,
        p_pay_terms                 IN VARCHAR2,
        p_approver                  IN VARCHAR2,
        p_date_sent_approver        IN VARCHAR2,
        p_misc_notes                IN VARCHAR2,
        p_chargeback                IN VARCHAR2,
        p_inv_num_d                 IN VARCHAR2,
        p_payment_ref               IN VARCHAR2,
        p_sample_invoice            IN VARCHAR2,
        p_asset_book                IN VARCHAR2,
        p_distribution_set          IN VARCHAR2, /*Changes as a part of CCR0007341*/
        p_inv_addl_info             IN VARCHAR2,
        p_pay_alone                 IN VARCHAR2,
        pv_attribute1               IN VARCHAR2,
        pv_attribute2               IN VARCHAR2,
        pv_attribute3               IN VARCHAR2,
        pv_attribute4               IN VARCHAR2,
        pv_attribute5               IN VARCHAR2,                     --gl_date
        pv_attribute6               IN VARCHAR2,                   --pay_group
        pv_attribute7               IN VARCHAR2,                --payment_hold
        pv_attribute8               IN VARCHAR2,             -- Invoice Source
        pv_attribute9               IN VARCHAR2,
        pv_attribute10              IN VARCHAR2,
        pv_attribute11              IN VARCHAR2,
        pv_attribute12              IN VARCHAR2,
        pv_attribute13              IN VARCHAR2,
        pv_attribute14              IN VARCHAR2,
        pv_attribute15              IN VARCHAR2,
        pv_attribute16              IN VARCHAR2,
        pv_attribute17              IN VARCHAR2,
        pv_attribute18              IN VARCHAR2,
        pv_attribute19              IN VARCHAR2,
        pv_attribute21              IN VARCHAR2,
        pv_attribute22              IN VARCHAR2,
        pv_attribute23              IN VARCHAR2,
        pv_attribute24              IN VARCHAR2,
        pv_attribute25              IN VARCHAR2,
        pv_attribute26              IN VARCHAR2,
        pv_attribute27              IN VARCHAR2,
        pv_attribute28              IN VARCHAR2,
        pv_attribute29              IN VARCHAR2,
        pv_attribute30              IN VARCHAR2 /* End of Changes as a part of CCR0007341*/
                                               )
    IS
        CURSOR hdr_cur IS
              SELECT po_number, invoice_number, operating_unit,
                     supplier, vendor_number, supplier_site,
                     invoice_date, invoice_amount, user_entered_tax,
                     tax_control_amt, fapio_received,           -- attribute10
                                                      currency_code,
                     hdr_description,  -- Added on 14-JUN-2017 for ENHC0013263
                                      payment_method, payment_terms,
                     gl_date, approver,                           --attribute4
                                        date_sent_approver,       --attribute2
                     misc_notes,                                  --attribute3
                                 chargeback,                      --attribute5
                                             invoice_number_d,    --attribute6
                     payment_ref,                                 --attribute7
                                  sample_invoice,                 --attribute8
                                                  unique_seq,
                     created_by, last_updated_by, po_number_l,
                     pay_alone,                   -- Changes as per CCR0007341
                                inv_addl_info, -- (attribute11) Changes as per CCR0007341
                                               source -- Added as per CCR0008507
                FROM xxdo.xxd_ap_inv_excel_upload_tbl
               WHERE     1 = 1
                     --AND source = 'EXCEL'
                     --AND SOURCE = g_invoice_source   -- Added as per CCR0008507
                     AND SOURCE IN ('LUCERNEX', 'EXCEL') -- Added as per CCR0008507
                     AND data_identifier = g_data_identifier
                     AND process_flag = g_new
                     AND created_by = apps.fnd_global.user_id
            /*AND  seq_no = (SELECT MAX(seq_no)
                            FROM xxdo.xxd_ap_inv_excel_upload_tbl
                           WHERE source = 'EXCEL'
                             AND data_identifier = G_DATA_IDENTIFIER
                             AND created_by = apps.fnd_global.user_id)*/
            GROUP BY invoice_number, operating_unit, supplier,
                     vendor_number, supplier_site, invoice_date,
                     po_number, invoice_amount, user_entered_tax,
                     tax_control_amt, fapio_received, currency_code,
                     hdr_description,  -- Added on 14-JUN-2017 for ENHC0013263
                                      payment_method, payment_terms,
                     gl_date, approver,                           --attribute4
                                        date_sent_approver,       --attribute2
                     misc_notes,                                  --attribute3
                                 chargeback,                      --attribute5
                                             invoice_number_d,    --attribute6
                     payment_ref,                                 --attribute7
                                  sample_invoice, unique_seq,
                     created_by, last_updated_by, po_number_l,
                     pay_alone,                   -- Changes as per CCR0007341
                                inv_addl_info,    -- Changes as per CCR0007341
                                               source -- Added as per CCR0008507
            ORDER BY invoice_date, operating_unit,                 --,Supplier
                                                   vendor_number,
                     invoice_number;

        CURSOR line_cur (p_invoice_num IN VARCHAR2, --,p_vendor_name   IN    VARCHAR2
                                                    p_vendor_num IN VARCHAR2, p_org_name IN VARCHAR2
                         , p_vendor_site IN VARCHAR2)
        IS
            SELECT line_type, description, line_amount,
                   dist_account, ship_to_location, po_number_l,
                   po_line_num, qty_invoiced, unit_price,
                   tax_classification_code, interco_exp_account,  --attribute2
                                                                 DEFERRED,
                   deferred_start_date, deferred_end_date, prorate,
                   track_as_asset, asset_category, asset_book,
                   distribution_set, unique_seq, seq_no,
                   track_as_asset
              FROM xxdo.xxd_ap_inv_excel_upload_tbl
             WHERE     1 = 1
                   --source = 'EXCEL'
                   --AND SOURCE = g_invoice_source                 -- Added as per CCR0008507
                   AND SOURCE IN ('LUCERNEX', 'EXCEL') -- Added as per CCR0008507
                   AND data_identifier = g_data_identifier
                   AND invoice_number = p_invoice_num            --invoice_num
                   AND operating_unit = p_org_name            --operating_unit
                   --AND supplier  = p_vendor_name --vendor_name
                   AND vendor_number = p_vendor_num
                   AND supplier_site = p_vendor_site             --vendor_site
                   AND created_by = apps.fnd_global.user_id;

        l_msg                  VARCHAR2 (4000);
        l_ret_msg              VARCHAR2 (4000) := NULL;
        ln_seq                 NUMBER;
        l_boolean              BOOLEAN;
        l_boolean1             BOOLEAN;
        l_hdr_count            NUMBER := 0;
        l_lin_count            NUMBER := 0;
        l_line_num             NUMBER;
        l_unique_seq           VARCHAR2 (100);
        lc_err_message         VARCHAR2 (4000);
        l_status               VARCHAR2 (1);
        l_po_header_inv_id     NUMBER;
        l_valid_org            NUMBER;
        l_resp_id              NUMBER;
        --header variables
        l_org_id               NUMBER;
        l_vendor_id            NUMBER;
        l_vendor_name          VARCHAR2 (100);
        l_site_id              NUMBER;
        l_pay_code             VARCHAR2 (50);
        l_terms_id             NUMBER;
        l_hdr_date             DATE;
        l_gl_date              DATE;
        l_invoice_id           NUMBER;
        l_invoice_amt          NUMBER;
        l_curr_code            VARCHAR2 (30);
        l_asset_book           VARCHAR2 (100);
        l_asset_cat_id         NUMBER;
        l_tax_control_amt      NUMBER;
        l_sample_inv_flag      VARCHAR2 (10);
        l_invoice_type         VARCHAR2 (100);
        l_email                VARCHAR2 (100);
        l_user_entered_tax     VARCHAR2 (100);
        l_fapio_flag           VARCHAR2 (10);
        l_pay_alone_flag       VARCHAR2 (10);
        ln_count_terms         NUMBER := 0;
        ln_count_pay_flag      NUMBER := 0;
        lv_param_value         VARCHAR2 (10);           --Added for change 1.3
        --line variables
        l_dist_acct_id         NUMBER;
        l_ship_to_code         VARCHAR2 (50);
        l_ship_to_loc_id       NUMBER;
        l_po_header_id         NUMBER;
        l_po_line_id           NUMBER;
        l_dist_set_id          NUMBER;
        l_line_type            VARCHAR2 (50);
        l_total_line_amount    NUMBER := 0;
        l_line_amt             NUMBER;
        l_invoice_line_id      NUMBER;
        l_vtx_prod_class       VARCHAR2 (150);
        l_interco_acct_id      NUMBER;
        l_deferred_flag        VARCHAR2 (10);
        l_prorate_flag         VARCHAR2 (10);
        l_asset_flag           VARCHAR2 (10);
        l_def_end_date         DATE;
        l_def_start_date       DATE;
        l_unit_price           NUMBER;
        l_tax_code             VARCHAR2 (100);
        l_valid_out            VARCHAR2 (100);
        lv_pay_group           VARCHAR2 (500);          --Added for change 1.3
        lv_payment_hold_flag   VARCHAR2 (2);            --Added for change 1.3
        lv_source              VARCHAR2 (100);
    BEGIN
        l_msg       := NULL;
        l_status    := NULL;
        lv_source   := NULL;

        SELECT TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS')
          INTO l_unique_seq
          FROM DUAL;

        /*======================*/
        --Get Org ID
        /*======================*/
        IF p_operating_unit IS NOT NULL
        THEN
            l_boolean   :=
                is_org_valid (p_org_name   => p_operating_unit,
                              x_org_id     => l_org_id,
                              x_ret_msg    => l_ret_msg);

            IF l_boolean = FALSE OR l_org_id IS NULL
            THEN
                l_status   := g_errored;
                l_msg      := l_msg || ' - ' || l_ret_msg;
            ELSIF l_boolean = TRUE OR l_org_id IS NOT NULL
            THEN
                BEGIN
                    SELECT hou.organization_id
                      INTO l_valid_org
                      FROM apps.hr_organization_units hou, apps.fnd_profile_options_vl fpo, apps.fnd_profile_option_values fpov,
                           apps.fnd_responsibility_vl frv, apps.per_security_profiles psp
                     WHERE     1 = 1
                           AND frv.responsibility_id = fnd_global.resp_id
                           AND fpov.level_value = frv.responsibility_id
                           AND UPPER (frv.responsibility_name) LIKE
                                   'DECKERS PAYABLES USER%'
                           AND fpo.profile_option_id = fpov.profile_option_id
                           AND fpo.user_profile_option_name =
                               'MO: Security Profile'
                           AND fpov.profile_option_id = fpo.profile_option_id
                           AND psp.security_profile_id =
                               fpov.profile_option_value
                           AND hou.NAME = psp.security_profile_name;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        l_status   := g_errored;
                        l_msg      :=
                               l_msg
                            || ' Please select valid Payables user responsibility ';
                    WHEN OTHERS
                    THEN
                        l_status   := g_errored;
                        l_msg      :=
                               l_msg
                            || ' Exception while selecting responsibility - '
                            || SQLERRM;
                END;

                IF l_valid_org IS NOT NULL
                THEN
                    IF l_org_id <> l_valid_org
                    THEN
                        l_status   := g_errored;
                        l_msg      :=
                               l_msg
                            || ' - '
                            || ' OU selected is different than that is available in Spread Sheet ';
                    END IF;
                END IF;
            END IF;
        ELSE
            l_msg   := l_msg || ' Operating Unit cannot be NULL ';
        END IF;

        /*=========================*/
        -- Validate to receive email
        /*=========================*/
        BEGIN
            l_ret_msg   := NULL;
            l_email     := NULL;
            l_email     := get_email (x_ret_msg => l_ret_msg);

            IF l_email IS NULL OR l_ret_msg IS NOT NULL
            THEN
                l_status   := g_errored;
                l_msg      :=
                       ' Please check whether the email id attached to your user '
                    || ' - '
                    || l_ret_msg;
            ELSE
                NULL;
            END IF;
        END;

        /*======================*/
        --Get Vendor ID
        /*======================*/
        IF p_vendor_number IS NOT NULL
        THEN
            l_boolean   := NULL;
            l_ret_msg   := NULL;
            l_boolean   :=
                is_vendor_valid (p_vendor_number => p_vendor_number, x_vendor_name => l_vendor_name, x_vendor_id => l_vendor_id
                                 , x_ret_msg => l_ret_msg);

            IF l_boolean = FALSE OR l_vendor_id IS NULL
            THEN
                l_status   := g_errored;
                l_msg      := l_msg || ' - ' || l_ret_msg;
            END IF;
        ELSE
            l_msg   := l_msg || ' Supplier Number cannot be NULL ';
        END IF;

        /*==================*/
        --Get Vendor Site ID
        /*==================*/
        IF l_vendor_id IS NOT NULL AND p_vednor_site_code IS NOT NULL
        THEN
            l_boolean   := NULL;
            l_ret_msg   := NULL;
            l_boolean   :=
                is_site_valid (p_site_code   => p_vednor_site_code,
                               p_org_id      => l_org_id,
                               p_vendor_id   => l_vendor_id,
                               x_site_id     => l_site_id,
                               x_ret_msg     => l_ret_msg);

            IF l_boolean = FALSE OR l_site_id IS NULL
            THEN
                l_status   := g_errored;
                l_msg      := l_msg || l_ret_msg;
            END IF;
        ELSE
            l_msg   :=
                   l_msg
                || ' Please check whether Supplier and Supplier site are Valid ';
        END IF;

        /*==================*/
        --Currency, Payment Terms and Payment Method
        /*==================*/
        IF l_org_id IS NULL OR l_vendor_id IS NULL OR l_site_id IS NULL
        THEN
            l_status    := g_errored;
            l_ret_msg   :=
                'Valid Operating Unit, Supplier and Supplier Site are Mandatory for Currency, payment Method and Payment terms';
            l_msg       := l_msg || l_ret_msg;
        END IF;

        /*==================*/
        --Validate and Get Currency code
        /*==================*/
        IF p_currency_code IS NOT NULL
        THEN
            l_boolean   := NULL;
            l_ret_msg   := NULL;
            l_boolean   :=
                is_curr_code_valid (p_curr_code   => p_currency_code,
                                    x_ret_msg     => l_ret_msg);

            IF l_boolean = FALSE
            THEN
                l_status   := g_errored;
                l_msg      := l_msg || ' - ' || l_ret_msg;
            ELSE
                l_curr_code   := p_currency_code;
            END IF;
        ELSIF p_currency_code IS NULL
        THEN
            IF     l_org_id IS NOT NULL
               AND l_vendor_id IS NOT NULL
               AND l_site_id IS NOT NULL
            THEN
                l_boolean   := NULL;
                l_ret_msg   := NULL;
                l_boolean   :=
                    get_curr_code (p_vendor_id        => l_vendor_id,
                                   p_vendor_site_id   => l_site_id,
                                   p_org_id           => l_org_id,
                                   x_curr_code        => l_curr_code,
                                   x_ret_msg          => l_ret_msg);

                IF l_boolean = FALSE OR l_curr_code IS NULL
                THEN
                    l_status   := g_errored;
                    l_msg      := l_msg || l_ret_msg;
                END IF;
            --ELSE
            --   l_msg := l_msg||' Valid OU and Supplier and Site are mandatory for Currency code ';
            END IF;
        END IF;

        /*==================*/
        --Get Payment Method
        /*==================*/
        IF     l_org_id IS NOT NULL
           AND l_vendor_id IS NOT NULL
           AND l_site_id IS NOT NULL
        THEN
            l_boolean   := NULL;
            l_ret_msg   := NULL;
            l_boolean   :=
                get_pay_method (p_vendor_id        => l_vendor_id,
                                p_vendor_site_id   => l_site_id,
                                p_org_id           => l_org_id,
                                x_pay_method       => l_pay_code,
                                x_ret_msg          => l_ret_msg);

            IF l_boolean = FALSE OR l_pay_code IS NULL
            THEN
                l_status   := g_errored;
                l_msg      := l_msg || l_ret_msg;
            END IF;
        --ELSE
        --   l_msg := l_msg||' Valid OU and Supplier and Site are mandatory for Payment method code ';
        END IF;

        /*==================*/
        --Valdiate Terms
        /*==================*/
        IF p_pay_terms IS NOT NULL
        THEN
            l_boolean   := NULL;
            l_ret_msg   := NULL;

            SELECT COUNT (1)
              INTO ln_count_terms
              FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values ffv
             WHERE     ffvs.flex_value_set_id = ffv.flex_value_set_id
                   AND ffvs.flex_value_set_name = 'XXD_AP_OVERRIDE_TERMS_VS'
                   AND NVL (ffv.enabled_flag, 'Y') = 'Y'
                   AND SYSDATE BETWEEN NVL (ffv.start_date_active, SYSDATE)
                                   AND NVL (ffv.end_date_active, SYSDATE)
                   AND UPPER (ffv.flex_value) =
                       TRIM (UPPER (p_operating_unit));

            IF ln_count_terms > 0
            THEN
                l_boolean   :=
                    is_term_valid (p_terms     => p_pay_terms,
                                   x_term_id   => l_terms_id,
                                   x_ret_msg   => l_ret_msg);

                IF l_boolean = FALSE OR l_terms_id IS NULL
                THEN
                    l_status   := g_errored;
                    l_msg      := l_msg || l_ret_msg;
                END IF;
            END IF;
        ELSE
            /*==================*/
            --Get Payment Terms
            /*==================*/
            IF     l_org_id IS NOT NULL
               AND l_vendor_id IS NOT NULL
               AND l_site_id IS NOT NULL
            THEN
                l_boolean   := NULL;
                l_ret_msg   := NULL;
                l_boolean   :=
                    get_terms (p_vendor_id        => l_vendor_id,
                               p_vendor_site_id   => l_site_id,
                               p_org_id           => l_org_id,
                               x_term_id          => l_terms_id,
                               x_ret_msg          => l_ret_msg);

                IF l_boolean = FALSE OR l_terms_id IS NULL
                THEN
                    l_status   := g_errored;
                    l_msg      := l_msg || l_ret_msg;
                END IF;
            --ELSE
            --   l_msg := l_msg||' Valid OU and Supplier and Site are mandatory for Payment Terms ';
            END IF;
        END IF;

        /*======================*/
        --Validate Invoice Date
        /*======================*/
        IF p_invoice_date IS NOT NULL
        THEN
            l_boolean   := NULL;
            l_ret_msg   := NULL;

            BEGIN
                SELECT TO_DATE (TO_CHAR (TO_DATE (p_invoice_date), g_format_mask), g_format_mask)
                  INTO l_hdr_date
                  FROM DUAL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_hdr_date   := NULL;
                    l_ret_msg    :=
                           ' Invalid Invoice date format. Please enter in the format: '
                        || g_format_mask;
            END;

            IF l_ret_msg IS NOT NULL
            THEN
                l_status   := g_errored;
                l_msg      := l_msg || l_ret_msg;
            END IF;
        ELSE
            l_msg   := l_msg || ' Invoice date cannot be NULL ';
        END IF;

        /*======================*/
        --Validate GL Date
        /*======================*/
        l_boolean   := NULL;
        l_ret_msg   := NULL;

        --Commented below code for change 1.3
        /* BEGIN
                SELECT TO_DATE(TO_CHAR(TO_DATE(SYSDATE),G_FORMAT_MASK),G_FORMAT_MASK)
                  INTO l_gl_date
                  FROM DUAL;
             EXCEPTION
                WHEN OTHERS THEN
                   l_gl_date := NULL;
                   l_status := G_ERRORED;
                   l_ret_msg := ' Invalid GL date format. Please enter in the format: '||G_FORMAT_MASK;
                   l_msg    := l_msg||l_ret_msg;
             END;*/
        /* start of changes for change 1.3*/
        IF pv_attribute5 IS NULL
        THEN
            BEGIN
                SELECT TO_DATE (TO_CHAR (TO_DATE (SYSDATE), g_format_mask), g_format_mask), 'N'
                  INTO l_gl_date, lv_param_value
                  FROM DUAL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_gl_date   := NULL;
                    l_status    := g_errored;
                    l_ret_msg   :=
                           ' Invalid GL date format. Please enter in the format: '
                        || g_format_mask;
                    l_msg       := l_msg || l_ret_msg;
            END;
        ELSE
            BEGIN
                SELECT TO_DATE (TO_CHAR (TO_DATE (pv_attribute5), g_format_mask), g_format_mask), 'Y'
                  INTO l_gl_date, lv_param_value
                  FROM DUAL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_gl_date   := NULL;
                    l_status    := g_errored;
                    l_ret_msg   :=
                           ' Invalid GL date format. Please enter in the format: '
                        || g_format_mask;
                    l_msg       := l_msg || l_ret_msg;
            END;
        END IF;

        l_gl_date   :=
            is_gl_date_valid (p_gl_date => l_gl_date, p_org_id => l_org_id, p_param_value => lv_param_value --Added for change 1.3
                              , x_ret_msg => l_ret_msg);

        IF l_gl_date IS NULL OR l_ret_msg IS NOT NULL
        THEN
            l_status   := g_errored;
            l_msg      := l_msg || l_ret_msg;
        END IF;

        /* end of changes for change 1.3*/

        /* start of changes for change 1.3*/
        /*======================*/
        --Validate pay_group
        /*======================*/
        IF pv_attribute6 IS NOT NULL
        THEN
            l_boolean      := NULL;
            l_ret_msg      := NULL;
            lv_pay_group   := NULL;
            l_boolean      :=
                is_pay_group_valid (p_pay_group   => pv_attribute6,
                                    x_code        => lv_pay_group,
                                    x_ret_msg     => l_ret_msg);

            IF l_boolean = FALSE OR l_ret_msg IS NOT NULL
            THEN
                l_status   := g_errored;
                l_msg      := l_msg || 'Pay_group: ' || l_ret_msg;
            END IF;
        ELSE
            lv_pay_group   := NULL;
        END IF;

        /* End of changes for change 1.3*/

        /* start of changes for change 1.3*/
        /*======================*/
        --Validate payment_hold flag
        /*======================*/
        IF pv_attribute7 IS NOT NULL
        THEN
            l_boolean              := NULL;
            l_ret_msg              := NULL;
            lv_payment_hold_flag   := NULL;
            l_boolean              :=
                is_flag_valid (p_flag      => pv_attribute7,
                               x_flag      => lv_payment_hold_flag,
                               x_ret_msg   => l_ret_msg);

            IF l_boolean = FALSE OR lv_payment_hold_flag IS NULL
            THEN
                l_status   := g_errored;
                l_msg      := l_msg || 'Payment_hold Flag' || l_ret_msg;
            END IF;
        ELSE
            lv_payment_hold_flag   := NULL;
        END IF;

        /* End of changes for change 1.3*/

        -- start of changes forCCR0008507

        /*======================*/
        --Validate Invoice Source
        /*======================*/
        IF pv_attribute8 IS NOT NULL
        THEN
            l_boolean   := NULL;
            l_ret_msg   := NULL;
            lv_source   := NULL;
            l_boolean   :=
                get_invoice_source (p_inv_source   => pv_attribute8,
                                    x_source       => lv_source,
                                    x_ret_msg      => l_ret_msg);

            IF l_boolean = FALSE OR lv_source IS NULL
            THEN
                l_status   := g_errored;
                l_msg      := l_msg || 'Source: ' || l_ret_msg;
            END IF;
        ELSE
            l_msg   := l_msg || ' Invoice Source cannot be NULL ';
        END IF;

        -- End of Change CCR0008507

        /*======================*/
        --Validate Invoice num
        /*======================*/
        IF p_invoice_num IS NOT NULL
        THEN
            l_boolean   := NULL;
            l_ret_msg   := NULL;
            l_boolean   :=
                is_inv_num_valid (p_inv_num => p_invoice_num, p_vendor_id => l_vendor_id, p_org_id => l_org_id
                                  , x_ret_msg => l_ret_msg);

            IF l_boolean = FALSE OR l_ret_msg IS NOT NULL
            THEN
                l_status   := g_errored;
                l_msg      := l_msg || l_ret_msg;
            END IF;
        ELSE
            l_status   := g_errored;
            l_msg      := l_msg || ' Invoice Number Cannot be NULL ';
        END IF;

        /*=============================*/
        --Validate invoice amount
        /*============================*/
        IF p_inv_amount IS NOT NULL
        THEN
            l_boolean   := NULL;
            l_ret_msg   := NULL;
            l_boolean   :=
                validate_amount (p_amount    => p_inv_amount,
                                 x_amount    => l_invoice_amt,
                                 x_ret_msg   => l_ret_msg);

            IF l_boolean = FALSE OR l_ret_msg IS NOT NULL
            THEN
                l_status   := g_errored;
                l_msg      := l_msg || l_ret_msg;
            END IF;
        ELSE
            l_status   := g_errored;
            l_msg      := l_msg || ' Invoice Amount Cannot be NULL ';
        END IF;

        /*==================================*/
        --Validate Credit or Standard Invoice
        /*==================================*/
        IF l_invoice_amt < 0
        THEN
            l_invoice_type   := 'CREDIT';
        ELSE
            l_invoice_type   := 'STANDARD';
        END IF;

        /*======================*/
        --Validate line type
        /*======================*/
        IF p_line_type IS NOT NULL
        THEN
            l_boolean   := NULL;
            l_ret_msg   := NULL;
            l_boolean   :=
                is_line_type_valid (p_line_type   => p_line_type,
                                    x_code        => l_line_type,
                                    x_ret_msg     => l_ret_msg);

            IF l_boolean = FALSE OR l_line_type IS NULL
            THEN
                l_status   := g_errored;
                l_msg      := l_msg || l_ret_msg;
            END IF;
        ELSE
            l_status   := g_errored;
            l_msg      := l_msg || ' Line Type Cannot be NULL ';
        END IF;

        /*=============================*/
        --Validate distribution account
        /*============================*/
        IF p_dist_account IS NOT NULL
        THEN
            IF p_po_number_l IS NOT NULL
            THEN
                l_status   := g_errored;
                l_msg      :=
                       l_msg
                    || ' Distribution account cannot be entered for PO Invoices ';
            ELSE
                l_boolean   := NULL;
                l_ret_msg   := NULL;
                l_boolean   :=
                    dist_account_exists (p_dist_acct   => p_dist_account,
                                         x_dist_ccid   => l_dist_acct_id,
                                         x_ret_msg     => l_ret_msg);

                IF l_boolean = FALSE OR l_dist_acct_id IS NULL
                THEN
                    l_status   := g_errored;
                    l_msg      := l_msg || l_ret_msg;
                END IF;
            END IF;
        ELSIF     p_po_number_l IS NULL
              AND (p_dist_account IS NULL OR p_distribution_set IS NULL)
        THEN
            l_status   := g_errored;
            l_msg      :=
                   l_msg
                || ' Distribution Account or Distribution set has to be entered ';
        END IF;

        /*=============================*/
        --Validate distribution set
        /*============================*/
        IF p_distribution_set IS NOT NULL
        THEN
            l_boolean   := NULL;
            l_ret_msg   := NULL;
            l_boolean   :=
                dist_set_exists (p_dist_set_name => p_distribution_set, p_org_id => l_org_id, x_dist_id => l_dist_set_id
                                 , x_ret_msg => l_ret_msg);
        END IF;

        IF p_po_number_l IS NULL
        THEN
            IF p_dist_account IS NULL AND p_distribution_set IS NULL
            THEN
                l_status   := g_errored;
                l_msg      :=
                       l_msg
                    || ' Either of Distribution Account or Distribution set are to be entered. ';
            ELSIF     p_dist_account IS NOT NULL
                  AND p_distribution_set IS NOT NULL
            THEN
                l_status   := g_errored;
                l_msg      :=
                       l_msg
                    || ' Both Distribution Account and Distribution set are entered. ';
            END IF;
        END IF;

        /*=============================*/
        --Validate ship to location
        /*============================*/
        IF p_ship_to_location IS NOT NULL          --AND p_po_number_l IS NULL
        THEN
            l_boolean   := NULL;
            l_ret_msg   := NULL;
            l_boolean   :=
                is_ship_to_valid (p_ship_to_code     => p_ship_to_location,
                                  x_ship_to_loc_id   => l_ship_to_loc_id,
                                  x_ret_msg          => l_ret_msg);

            IF l_boolean = FALSE OR l_ship_to_loc_id IS NULL
            THEN
                l_status   := g_errored;
                l_msg      := l_msg || l_ret_msg;
            END IF;
        --ELSE
        /*IF l_dist_acct_id IS NOT NULL and l_org_id IS NOT NULL AND p_po_number_l IS NULL
        THEN
           BEGIN
             SELECT   fv.attribute13
               INTO   l_ship_to_loc_id
               FROM   apps.fnd_id_flex_structures_tl ffs,
                      apps.fnd_id_flex_segments_vl fs,
                      apps.fnd_flex_values fv,
                      apps.gl_code_combinations gcc
              WHERE   gcc.code_combination_id = l_dist_acct_id
                AND   ffs.id_flex_num = gcc.chart_of_accounts_id -- Links to gl_ledgers.chart_of_accounts_id
                AND   ffs.id_flex_code = 'GL#'
                AND   ffs.language = USERENV ('LANG')
                AND   ffs.id_flex_num = fs.id_flex_num
                AND   ffs.id_flex_code = fs.id_flex_code
                AND   fs.application_column_name = 'SEGMENT5'
                AND   fs.flex_value_set_id = fv.flex_value_set_id
                AND   fv.flex_value = gcc.segment5;

                IF l_ship_to_loc_id IS NULL
                THEN
                   SELECT  location_id
                     INTO  l_ship_to_loc_id
                     FROM  apps.hr_all_organization_units
                    WHERE  organization_id = l_org_id;
                END IF;

           EXCEPTION
             WHEN NO_DATA_FOUND
             THEN
                SELECT  location_id
                  INTO  l_ship_to_loc_id
                  FROM  apps.hr_all_organization_units
                 WHERE  organization_id = l_org_id;
             WHEN OTHERS
             THEN
                l_ship_to_loc_id := NULL;
                l_ret_msg:= 'Exception in Ship to Location '||substr(sqlerrm,1,200);
           END;
            IF l_ship_to_loc_id IS NULL THEN
            l_status := G_ERRORED;
            l_msg := l_msg||l_ret_msg;
            END IF;
        END IF;*/
        END IF;

        /*=================================================*/
        -- Validate PO Number at Header and PO Number at Line
        /*=================================================*/
        IF p_po_number IS NOT NULL
        THEN
            IF p_po_number_l IS NULL
            THEN
                l_status   := g_errored;
                l_msg      :=
                       l_msg
                    || ' PO Number at Invoice Header require PO Number at Invoice Line level ';
            ELSIF p_po_number_l IS NOT NULL
            THEN
                IF p_po_number <> p_po_number_l
                THEN
                    l_status   := g_errored;
                    l_msg      :=
                           l_msg
                        || ' PO Number at Invoice Header should be same as PO Number at invoice Line level ';
                END IF;
            END IF;
        END IF;

        /*=====================================*/
        --Validate PO Number at Invoice Header
        /*=====================================*/
        IF l_org_id IS NOT NULL AND l_vendor_id IS NOT NULL
        THEN
            IF p_po_number IS NOT NULL
            THEN
                l_boolean   := NULL;
                l_ret_msg   := NULL;
                l_boolean   :=
                    is_po_exists (p_po_num         => p_po_number,
                                  p_vendor_id      => l_vendor_id,
                                  p_org_id         => l_org_id,
                                  x_po_header_id   => l_po_header_inv_id,
                                  x_ret_msg        => l_ret_msg);

                IF l_boolean = FALSE OR l_po_header_inv_id IS NULL
                THEN
                    l_status   := g_errored;
                    l_msg      :=
                           ' PO Number at Invoice Header - '
                        || l_msg
                        || l_ret_msg;
                END IF;
            END IF;
        END IF;

        /*=======================================*/
        --Validate PO Number at Invoice Line Level
        /*=======================================*/
        IF l_org_id IS NOT NULL AND l_vendor_id IS NOT NULL
        THEN
            IF p_po_number_l IS NOT NULL
            THEN
                l_boolean   := NULL;
                l_ret_msg   := NULL;
                l_boolean   :=
                    is_po_exists (p_po_num         => p_po_number_l,
                                  p_vendor_id      => l_vendor_id,
                                  p_org_id         => l_org_id,
                                  x_po_header_id   => l_po_header_id,
                                  x_ret_msg        => l_ret_msg);

                IF l_boolean = FALSE OR l_po_header_id IS NULL
                THEN
                    l_status   := g_errored;
                    l_msg      := l_msg || l_ret_msg;
                END IF;
            END IF;
        END IF;

        /*=============================*/
        --Validate PO Line
        /*============================*/
        IF     l_org_id IS NOT NULL
           AND l_vendor_id IS NOT NULL
           AND l_po_header_id IS NOT NULL
        THEN
            IF p_po_line_num IS NOT NULL
            THEN
                l_boolean   := NULL;
                l_ret_msg   := NULL;
                l_boolean   :=
                    is_po_line_exists (p_line_num     => p_po_line_num,
                                       p_org_id       => l_org_id,
                                       p_header_id    => l_po_header_id,
                                       x_po_line_id   => l_po_line_id,
                                       x_ret_msg      => l_ret_msg);

                IF l_boolean = FALSE OR l_po_header_id IS NULL
                THEN
                    l_status   := g_errored;
                    l_msg      := l_msg || l_ret_msg;
                END IF;
            END IF;
        END IF;

        /*======================*/
        --Validate Quantity Invoiced
        /*======================*/
        IF p_qty_invoiced IS NOT NULL AND p_qty_invoiced < 0
        THEN
            l_boolean   := FALSE;
            l_msg       := l_msg || ' Quantity Invoiced cannot be Neagtive. ';
            l_status    := g_errored;
        END IF;

        /*======================*/
        --Validate Unit Price
        /*======================*/
        IF p_unit_price IS NOT NULL
        THEN
            l_boolean   := NULL;
            l_ret_msg   := NULL;
            l_boolean   :=
                validate_amount (p_amount    => p_unit_price,
                                 x_amount    => l_unit_price,
                                 x_ret_msg   => l_ret_msg);

            IF l_boolean = FALSE OR l_ret_msg IS NOT NULL
            THEN
                l_status   := g_errored;
                l_msg      := l_msg || ' - ' || l_ret_msg;
            END IF;
        END IF;

        /*===========================================*/
        -- Validate PO Unit Price and PO Qty Invoiced
        /*===========================================*/
        IF p_po_number_l IS NOT NULL AND p_po_line_num IS NOT NULL
        THEN
            IF p_qty_invoiced IS NULL OR p_unit_price IS NULL
            THEN
                l_status   := g_errored;
                l_msg      :=
                       l_msg
                    || ' - '
                    || 'Quantity invoiced and Unit Price has to be entered for PO related invoices ';
            END IF;
        END IF;

        /*=======================*/
        -- Validate Line Amount
        /*=======================*/
        IF p_line_amount IS NOT NULL
        THEN
            l_boolean   := NULL;
            l_ret_msg   := NULL;
            l_boolean   :=
                validate_amount (p_amount    => p_line_amount,
                                 x_amount    => l_line_amt,
                                 x_ret_msg   => l_ret_msg);

            IF l_boolean = FALSE OR l_line_amt IS NULL
            THEN
                l_status   := g_errored;
                l_msg      := l_msg || l_ret_msg;
            END IF;
        ELSE
            l_status   := g_errored;
            l_msg      := l_msg || ' Line amount cannot be NULL ';
        END IF;

        /*============================*/
        -- Vendor Charged Tax
        /*============================*/
        IF p_user_entered_tax IS NOT NULL
        THEN
            l_boolean   := NULL;
            l_ret_msg   := NULL;
            l_boolean   :=
                validate_amount (p_amount    => p_user_entered_tax,
                                 x_amount    => l_user_entered_tax,
                                 x_ret_msg   => l_ret_msg);

            IF l_boolean = FALSE OR l_user_entered_tax IS NULL
            THEN
                l_status   := g_errored;
                l_msg      := l_msg || l_ret_msg;
            END IF;
        END IF;

        /*=============================*/
        --Get Asset Book
        /*============================*/
        IF p_asset_book IS NOT NULL
        THEN
            l_boolean    := NULL;
            l_ret_msg    := NULL;
            l_boolean1   := NULL;
            l_boolean    :=
                get_asset_book (p_asset_book   => p_asset_book,
                                x_asset_book   => l_asset_book,
                                x_ret_msg      => l_ret_msg);

            IF l_boolean = FALSE OR l_asset_book IS NULL
            THEN
                l_status   := g_errored;
                l_msg      := l_msg || l_ret_msg;
            ELSIF l_boolean = TRUE OR l_asset_book IS NOT NULL
            THEN
                l_boolean1   :=
                    is_asset_book_valid (p_asset_book   => l_asset_book,
                                         p_org_id       => l_org_id,
                                         x_ret_msg      => l_ret_msg);

                IF l_boolean1 = FALSE OR l_ret_msg IS NOT NULL
                THEN
                    l_status   := g_errored;
                    l_msg      := l_msg || l_ret_msg;
                END IF;
            END IF;
        END IF;

        /*=============================*/
        --Get Asset Category
        /*============================*/
        IF p_asset_book IS NOT NULL
        THEN
            l_boolean    := NULL;
            l_boolean1   := NULL;
            l_ret_msg    := NULL;
            l_boolean    :=
                get_asset_category (p_asset_cat      => p_asset_category,
                                    x_asset_cat_id   => l_asset_cat_id,
                                    x_ret_msg        => l_ret_msg);

            IF l_boolean = FALSE OR l_asset_cat_id IS NULL
            THEN
                l_status   := g_errored;
                l_msg      := l_msg || l_ret_msg;
            ELSIF l_boolean = TRUE OR l_asset_cat_id IS NOT NULL
            THEN
                l_boolean1   :=
                    is_asset_cat_valid (p_asset_cat_id   => l_asset_cat_id,
                                        p_asset_book     => p_asset_book --,x_valid_out    => l_valid_out
                                                                        ,
                                        x_ret_msg        => l_ret_msg);

                IF l_boolean1 = FALSE OR l_ret_msg IS NOT NULL
                THEN
                    l_status   := g_errored;
                    l_msg      := l_msg || l_ret_msg;
                END IF;
            END IF;
        END IF;

        /*==========================================*/
        --Validate interco account
        /*=========================================*/
        IF p_interco_exp_account IS NOT NULL AND l_dist_acct_id IS NOT NULL
        THEN
            l_boolean   := NULL;
            l_ret_msg   := NULL;
            l_boolean   :=
                is_interco_acct (p_interco_acct => p_interco_exp_account, p_dist_ccid => l_dist_acct_id, x_interco_acct_id => l_interco_acct_id
                                 , x_ret_msg => l_ret_msg);

            IF l_boolean = FALSE OR l_interco_acct_id IS NULL
            THEN
                l_status   := g_errored;
                l_msg      := l_msg || l_ret_msg;
            END IF;
        END IF;

        /*==========================================*/
        --Validate Deferred Flag
        /*=========================================*/
        IF p_deferred IS NOT NULL
        THEN
            l_boolean   := NULL;
            l_ret_msg   := NULL;
            l_boolean   :=
                is_flag_valid (p_flag      => p_deferred,
                               x_flag      => l_deferred_flag,
                               x_ret_msg   => l_ret_msg);

            IF l_boolean = FALSE OR l_deferred_flag IS NULL
            THEN
                l_status   := g_errored;
                l_msg      := l_msg || l_ret_msg;
            END IF;
        END IF;

        /*==========================================*/
        --Validate Prorate Flag
        /*=========================================*/
        IF p_prorate IS NOT NULL
        THEN
            l_boolean   := NULL;
            l_ret_msg   := NULL;
            l_boolean   :=
                is_flag_valid (p_flag      => p_prorate,
                               x_flag      => l_prorate_flag,
                               x_ret_msg   => l_ret_msg);

            IF l_boolean = FALSE OR l_deferred_flag IS NULL
            THEN
                l_status   := g_errored;
                l_msg      := l_msg || l_ret_msg;
            END IF;
        END IF;

        /*==========================================*/
        --FAPIO Received Flag
        /*=========================================*/
        IF p_fapio_received IS NOT NULL
        THEN
            l_boolean   := NULL;
            l_ret_msg   := NULL;
            l_boolean   :=
                is_flag_valid (p_flag      => p_fapio_received,
                               x_flag      => l_fapio_flag,
                               x_ret_msg   => l_ret_msg);

            IF l_boolean = FALSE OR l_fapio_flag IS NULL
            THEN
                l_status   := g_errored;
                l_msg      := l_msg || l_ret_msg;
            END IF;
        END IF;

        /*==========================================*/
        --Track as asset Flag
        /*=========================================*/
        IF p_track_as_asset IS NOT NULL
        THEN
            l_boolean   := NULL;
            l_ret_msg   := NULL;
            l_boolean   :=
                is_flag_valid (p_flag      => p_track_as_asset,
                               x_flag      => l_asset_flag,
                               x_ret_msg   => l_ret_msg);

            IF l_boolean = FALSE OR l_asset_flag IS NULL
            THEN
                l_status   := g_errored;
                l_msg      := l_msg || l_ret_msg;
            END IF;
        END IF;

        /*==========================================*/
        --Validate Asset Information
        /*=========================================*/
        IF     l_asset_flag = 'Y'
           AND (p_asset_category IS NULL OR p_asset_book IS NULL)
        THEN
            l_status   := g_errored;
            l_msg      :=
                   l_msg
                || ' Please check asset category and asset book values. ';
        ELSIF     p_asset_book IS NOT NULL
              AND (p_track_as_asset IS NULL OR l_asset_flag = 'N' OR p_asset_category IS NULL)
        THEN
            l_status   := g_errored;
            l_msg      :=
                   l_msg
                || ' Please check asset Category and Track as asset values. ';
        ELSIF     p_asset_category IS NOT NULL
              AND (p_track_as_asset IS NULL OR l_asset_flag = 'N' OR p_asset_book IS NULL)
        THEN
            l_status   := g_errored;
            l_msg      :=
                   l_msg
                || ' Please check asset book and Track as asset values. ';
        ELSIF     p_asset_category IS NOT NULL
              AND p_track_as_asset IS NOT NULL
              AND l_asset_flag = 'Y'
              AND p_asset_book IS NOT NULL
        THEN
            IF p_po_number_l IS NULL
            THEN
                l_status   := g_errored;
                l_msg      :=
                       l_msg
                    || ' Asset cannot be entered without Purchase Order. ';
            END IF;
        END IF;

        /*==========================================*/
        --Validate Sample Invoice flag
        /*=========================================*/
        IF p_sample_invoice IS NOT NULL
        THEN
            l_boolean   := NULL;
            l_ret_msg   := NULL;
            l_boolean   :=
                is_flag_valid (p_flag      => p_sample_invoice,
                               x_flag      => l_sample_inv_flag,
                               x_ret_msg   => l_ret_msg);

            IF l_boolean = FALSE OR l_sample_inv_flag IS NULL
            THEN
                l_status   := g_errored;
                l_msg      := l_msg || l_ret_msg;
            END IF;
        END IF;

        /*============================*/
        --Validate Deferred Start date
        /*============================*/
        IF p_deferred_start_date IS NOT NULL
        THEN
            l_boolean   := NULL;
            l_ret_msg   := NULL;

            BEGIN
                SELECT TO_DATE (TO_CHAR (TO_DATE (p_deferred_start_date), g_format_mask), g_format_mask)
                  INTO l_def_start_date
                  FROM DUAL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_hdr_date   := NULL;
                    l_ret_msg    :=
                           ' Invalid deferred start date format. Please enter in the format: '
                        || g_format_mask;
            END;

            IF l_ret_msg IS NOT NULL
            THEN
                l_status   := g_errored;
                l_msg      := l_msg || l_ret_msg;
            END IF;
        END IF;

        /*======================*/
        --Validate Deferred End date
        /*======================*/
        IF p_deferred_end_date IS NOT NULL
        THEN
            l_boolean   := NULL;
            l_ret_msg   := NULL;

            BEGIN
                SELECT TO_DATE (TO_CHAR (TO_DATE (p_deferred_end_date), g_format_mask), g_format_mask)
                  INTO l_def_end_date
                  FROM DUAL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_hdr_date   := NULL;
                    l_ret_msg    :=
                           ' Invalid deferred end date format. Please enter in the format: '
                        || g_format_mask;
            END;

            IF l_ret_msg IS NOT NULL
            THEN
                l_status   := g_errored;
                l_msg      := l_msg || l_ret_msg;
            END IF;
        END IF;

        /*==========================================*/
        --Validate Deferred Option details
        /*=========================================*/
        IF     l_deferred_flag = 'Y'
           AND (p_deferred_start_date IS NULL OR p_deferred_end_date IS NULL)
        THEN
            l_status   := g_errored;
            l_msg      :=
                   l_msg
                || ' Please enter valid deferred start and end date values. ';
        ELSIF     p_deferred_start_date IS NOT NULL
              AND (p_deferred IS NULL OR l_deferred_flag = 'N' OR p_deferred_end_date IS NULL)
        THEN
            l_status   := g_errored;
            l_msg      :=
                   l_msg
                || ' Please enter valid deferred and deferred end date values';
        ELSIF     p_deferred_end_date IS NOT NULL
              AND (p_deferred IS NULL OR l_deferred_flag = 'N' OR p_deferred_start_date IS NULL)
        THEN
            l_status   := g_errored;
            l_msg      :=
                   l_msg
                || ' Please enter valid deferred and deferred start date values';
        END IF;

        /*==========================*/
        --Validate Tax Control Amout
        /*==========================*/
        IF p_tax_control_amt IS NOT NULL
        THEN
            l_boolean   := NULL;
            l_ret_msg   := NULL;
            l_boolean   :=
                validate_amount (p_amount    => p_tax_control_amt,
                                 x_amount    => l_tax_control_amt,
                                 x_ret_msg   => l_ret_msg);

            IF l_boolean = FALSE OR l_ret_msg IS NOT NULL
            THEN
                l_status   := g_errored;
                l_msg      := l_msg || ' - ' || l_ret_msg;
            END IF;
        END IF;

        /*===============================*/
        --Validate Tax Classification Code
        /*===============================*/
        IF p_tax_classification_code IS NOT NULL
        THEN
            l_boolean   := NULL;
            l_ret_msg   := NULL;
            l_boolean   :=
                is_tax_code_valid (p_tax_code   => p_tax_classification_code,
                                   x_tax_code   => l_tax_code,
                                   x_ret_msg    => l_ret_msg);

            IF l_boolean = FALSE OR l_ret_msg IS NOT NULL
            THEN
                l_status   := g_errored;
                l_msg      := l_msg || ' - ' || l_ret_msg;
            END IF;
        END IF;

        -- Start of Changes as per CCR0007341

        /*==========================================*/
        --Validate Pay alone flag
        /*=========================================*/
        IF p_pay_alone IS NOT NULL
        THEN
            l_boolean   := NULL;
            l_ret_msg   := NULL;

            SELECT COUNT (1)
              INTO ln_count_pay_flag
              FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values ffv
             WHERE     ffvs.flex_value_set_id = ffv.flex_value_set_id
                   AND ffvs.flex_value_set_name = 'XXD_AP_OVERRIDE_TERMS_VS'
                   AND NVL (ffv.enabled_flag, 'Y') = 'Y'
                   AND SYSDATE BETWEEN NVL (ffv.start_date_active, SYSDATE)
                                   AND NVL (ffv.end_date_active, SYSDATE)
                   AND UPPER (ffv.flex_value) =
                       TRIM (UPPER (p_operating_unit));

            IF ln_count_pay_flag > 0
            THEN
                l_boolean   :=
                    is_flag_valid (p_flag      => p_pay_alone,
                                   x_flag      => l_pay_alone_flag,
                                   x_ret_msg   => l_ret_msg);

                IF l_boolean = FALSE OR l_pay_alone_flag IS NULL
                THEN
                    l_status   := g_errored;
                    l_msg      := l_msg || l_ret_msg;
                END IF;
            END IF;
        ELSE
            l_pay_alone_flag   := 'N';
        END IF;

        /*IF  p_pay_alone IS NOT NULL
        THEN
           l_boolean := NULL;
           l_ret_msg := NULL;
           l_boolean := is_flag_valid (p_flag      => p_pay_alone
                                       ,x_flag     => l_pay_alone_flag
                                       ,x_ret_msg  => l_ret_msg);
           IF l_boolean = FALSE OR l_pay_alone_flag IS NULL THEN
              l_status := G_ERRORED;
              l_msg := l_msg||l_ret_msg;
           END IF;
        END IF;*/

        -- End of Changes as per CCR0007341
        IF l_status <> g_errored OR l_status IS NULL
        THEN
            SELECT --inv_seq.NEXTVAL create new synonym in XXDO schema for change 1.3
                   xxd_ap_inv_seq.NEXTVAL INTO ln_seq FROM DUAL;

            INSERT INTO --XXDO_APINV_EXCEL_UPLOAD_TBL created new table in xxdo schema for change 1.3
                        xxdo.xxd_ap_inv_excel_upload_tbl (
                            po_number,
                            invoice_number,
                            operating_unit,
                            supplier,
                            vendor_number,
                            supplier_site,
                            invoice_date,
                            invoice_amount,
                            hdr_description,
                            user_entered_tax,
                            tax_control_amt,
                            fapio_received,
                            line_type,
                            description,
                            line_amount,
                            dist_account,
                            ship_to_location,
                            po_number_l,
                            po_line_num,
                            qty_invoiced,
                            unit_price,
                            tax_classification_code,
                            interco_exp_account,
                            DEFERRED,
                            deferred_start_date,
                            deferred_end_date,
                            prorate,
                            track_as_asset,
                            asset_category,
                            approver,
                            date_sent_approver,
                            misc_notes,
                            chargeback,
                            invoice_number_d,
                            payment_ref,
                            sample_invoice,
                            asset_book,
                            distribution_set,
                            unique_seq,
                            process_flag,
                            error_message,
                            created_by,
                            last_updated_by,
                            last_update_login,
                            creation_date,
                            last_update_date,
                            SOURCE,
                            data_identifier,
                            process_flag_l,
                            seq_no,
                            org_id,
                            vendor_id,
                            vendor_site_id,
                            currency_code,
                            payment_method,
                            payment_terms,
                            dist_account_id,
                            ship_to_location_id,
                            interco_exp_account_id,
                            dist_set_id,
                            po_header_id,
                            po_line_id,
                            po_header_l_id,
                            asset_book_code,
                            asset_cat_id,
                            prorate_flag,
                            deferred_flag,
                            asset_flag,
                            fapio_flag,
                            sample_inv_flag,
                            gl_date,
                            invoice_type_lookup_code,
                            pay_alone,              -- Added as per CCR0007341
                            inv_addl_info,          -- Added as per CCR0007341
                            pay_alone_flag,         -- Added as per CCR0007341
                            pay_group,                 -- Added for change 1.3
                            payment_hold               -- Added for change 1.3
                                        )
                 VALUES (p_po_number, p_invoice_num, p_operating_unit,
                         l_vendor_name, p_vendor_number, p_vednor_site_code,
                         l_hdr_date, l_invoice_amt, p_pay_method,
                         l_user_entered_tax, l_tax_control_amt, p_fapio_received, l_line_type, p_description, l_line_amt, p_dist_account, p_ship_to_location, p_po_number_l, p_po_line_num, p_qty_invoiced, p_unit_price, l_tax_code, --,p_tax_classification_code
                                                                                                                                                                                                                                      p_interco_exp_account, p_deferred, l_def_start_date, l_def_end_date, p_prorate, p_track_as_asset, p_asset_category, p_approver, p_date_sent_approver, p_misc_notes, p_chargeback, p_inv_num_d, p_payment_ref, p_sample_invoice, p_asset_book, p_distribution_set, g_unique_seq, --l_unique_seq
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      g_new, NULL, fnd_global.user_id, fnd_global.user_id, fnd_global.user_id, SYSDATE, SYSDATE, --,'EXCEL'
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 lv_source, --g_invoice_source,                      -- Added as per CCR0008507
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            g_data_identifier, g_new, ln_seq, --
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              l_org_id, l_vendor_id, l_site_id, l_curr_code, l_pay_code, l_terms_id, l_dist_acct_id, l_ship_to_loc_id, l_interco_acct_id, l_dist_set_id, l_po_header_inv_id, l_po_line_id, l_po_header_id, l_asset_book, l_asset_cat_id, l_prorate_flag, l_deferred_flag, l_asset_flag, l_fapio_flag, l_sample_inv_flag, l_gl_date, l_invoice_type, p_pay_alone, -- Added as per CCR0007341
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 p_inv_addl_info, -- Added as per CCR0007341
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  l_pay_alone_flag
                         ,                          -- Added as per CCR0007341
                           lv_pay_group,               -- Added for change 1.3
                                         lv_payment_hold_flag -- Added for change 1.3
                                                             );

            COMMIT;
        ELSE
            raise_application_error (-20101, 'Error - ' || SUBSTR (l_msg, 1));
        END IF;
    END;

    --- Insert data into Staging tables
    PROCEDURE insert_stg (x_ret_code OUT VARCHAR2, x_ret_msg OUT VARCHAR2)
    IS
        CURSOR hdr_cur IS
              SELECT po_number, invoice_number, operating_unit,
                     supplier, vendor_number, supplier_site,
                     invoice_date, invoice_amount, hdr_description, -- Added on 14-JUN-2017 for ENHC0013263
                     user_entered_tax, tax_control_amt, fapio_received,
                     currency_code, payment_method, payment_terms,
                     gl_date, approver,                           --attribute4
                                        date_sent_approver,       --attribute2
                     misc_notes,                                  --attribute3
                                 chargeback,                      --attribute5
                                             invoice_number_d,    --attribute6
                     payment_ref,                                 --attribute7
                                  sample_invoice,                 --attribute8
                                                  unique_seq,        --,seq_no
                     created_by, last_updated_by, org_id,
                     vendor_id, vendor_site_id, po_header_id,
                     fapio_flag, sample_inv_flag, invoice_type_lookup_code,
                     pay_alone,     -- Changes as per CCR0007341 (Attribute11)
                                inv_addl_info,    -- Changes as per CCR0007341
                                               pay_alone_flag, -- Changes as per CCR0007341
                     pay_group,                        -- Added for change 1.3
                                payment_hold,          -- Added for change 1.3
                                              source -- Added as per CCR0008507
                FROM xxdo.xxd_ap_inv_excel_upload_tbl
               WHERE     1 = 1
                     --AND source = 'EXCEL'
                     --AND SOURCE = g_invoice_source       -- Added as per CCR0008507
                     AND SOURCE IN ('LUCERNEX', 'EXCEL') -- Added as per CCR0008507
                     AND data_identifier = g_data_identifier
                     AND process_flag = g_new
                     AND created_by = apps.fnd_global.user_id
            GROUP BY invoice_number, operating_unit, supplier,
                     vendor_number, supplier_site, invoice_date,
                     po_number, invoice_amount, hdr_description, -- Added on 14-JUN-2017 for ENHC0013263
                     user_entered_tax, tax_control_amt, fapio_received,
                     currency_code, payment_method, payment_terms,
                     gl_date, approver,                           --attribute4
                                        date_sent_approver,       --attribute2
                     misc_notes,                                  --attribute3
                                 chargeback,                      --attribute5
                                             invoice_number_d,    --attribute6
                     payment_ref,                                 --attribute7
                                  sample_invoice, unique_seq,        --,seq_no
                     created_by, last_updated_by, org_id,
                     vendor_id, vendor_site_id, po_header_id,
                     fapio_flag, sample_inv_flag, invoice_type_lookup_code,
                     pay_alone,                   -- Changes as per CCR0007341
                                inv_addl_info,    -- Changes as per CCR0007341
                                               pay_alone_flag, -- Changes as per CCR0007341
                     pay_group,                        -- Added for change 1.3
                                payment_hold,          -- Added for change 1.3
                                              source -- Added as per CCR0008507
            ORDER BY invoice_date, operating_unit, vendor_number,
                     invoice_number;

        CURSOR line_cur (p_invoice_num IN VARCHAR2, p_vendor_num IN VARCHAR2 --,p_vendor_name   IN    VARCHAR2
                                                                            , p_org_name IN VARCHAR2
                         , p_vendor_site IN VARCHAR2)
        IS
            SELECT line_type, description, line_amount,
                   dist_account, ship_to_location, po_number_l,
                   po_line_num, qty_invoiced, unit_price,
                   tax_classification_code, interco_exp_account,  --attribute2
                                                                 DEFERRED,
                   deferred_start_date, deferred_end_date, prorate,
                   track_as_asset, asset_category, asset_book,
                   distribution_set, unique_seq, seq_no,
                   dist_account_id, ship_to_location_id, interco_exp_account_id,
                   dist_set_id, po_header_l_id, po_line_id,
                   asset_book_code, asset_cat_id, asset_flag,
                   prorate_flag, deferred_flag
              FROM xxdo.xxd_ap_inv_excel_upload_tbl
             WHERE     1 = 1
                   --AND source = 'EXCEL'
                   --AND SOURCE = g_invoice_source             -- Adsded as per CCR0008507
                   AND SOURCE IN ('LUCERNEX', 'EXCEL') -- Added as per CCR0008507
                   AND data_identifier = g_data_identifier
                   AND invoice_number = p_invoice_num            --invoice_num
                   AND operating_unit = p_org_name            --operating_unit
                   AND vendor_number = p_vendor_num
                   --AND supplier  = p_vendor_name --vendor_name
                   AND supplier_site = p_vendor_site             --vendor_site
                   AND created_by = apps.fnd_global.user_id;

        l_invoice_id          NUMBER;
        l_hdr_status          VARCHAR2 (1);
        l_line_status         VARCHAR2 (1);
        l_total_line_amount   NUMBER;
        l_invoice_line_id     NUMBER;
        l_lin_count           NUMBER;
        l_hdr_msg             VARCHAR2 (4000);
        l_lin_msg             VARCHAR2 (4000);
        -- Added for CCR0008507
        l_retn_msg            VARCHAR2 (4000);
        l_mtd_boolean         BOOLEAN;
        l_mtd_org_name        VARCHAR2 (100);
        l_mtd_flag            VARCHAR2 (1);
    -- End of Change
    BEGIN
        FOR hdr IN hdr_cur
        LOOP
            l_invoice_id          := NULL;
            l_hdr_status          := g_validated;
            l_hdr_msg             := NULL;
            l_lin_count           := 0;
            l_total_line_amount   := 0;

            BEGIN
                SELECT apps.ap_invoices_interface_s.NEXTVAL
                  INTO l_invoice_id
                  FROM DUAL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_invoice_id   := NULL;
            END;


            -- validate org is MTD OU (Added for CCR0008507)

            IF hdr.operating_unit IS NOT NULL
            THEN
                l_mtd_org_name   := NULL;
                l_retn_msg       := NULL;
                l_mtd_boolean    := FALSE;
                l_mtd_flag       := 'N';
                l_mtd_boolean    :=
                    is_mtd_org (p_org_name       => hdr.operating_unit,
                                x_mtd_org_name   => l_mtd_org_name,
                                x_ret_msg        => l_retn_msg);

                IF l_mtd_boolean = TRUE OR l_mtd_org_name IS NOT NULL
                THEN
                    l_mtd_flag   := 'Y';
                END IF;
            END IF;

            -- end of Change

            FOR line IN line_cur (p_invoice_num => hdr.invoice_number, p_vendor_num => hdr.vendor_number, --,p_vendor_name  => hdr.supplier
                                                                                                          p_org_name => hdr.operating_unit
                                  , p_vendor_site => hdr.supplier_site) --Line Loop Start
            LOOP
                l_line_status       := g_validated;
                l_invoice_line_id   := NULL;
                l_lin_msg           := NULL;

                BEGIN
                    l_lin_count   := l_lin_count + 1;
                    --l_total_line_amount   := l_total_line_amount + NVL(line.line_amount,0)+NVL(hdr.user_entered_tax,0)+NVL(hdr.tax_control_amt,0);
                    l_total_line_amount   :=
                        l_total_line_amount + NVL (line.line_amount, 0);

                    BEGIN
                        SELECT apps.ap_invoice_lines_interface_s.NEXTVAL
                          INTO l_invoice_line_id
                          FROM DUAL;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            l_invoice_line_id   := NULL;
                    END;

                    BEGIN
                        INSERT INTO --XXDO_APINV_UPLOAD_LINES  created new table in XXDO schema for change 1.3
                                    xxdo.xxd_ap_inv_upload_lines (
                                        line_number,
                                        line_type,
                                        line_description,
                                        ship_to_location_code,
                                        distribution_account,
                                        dist_account_ccid,
                                        ship_to_location_id,
                                        distribution_set,
                                        distribution_set_id,
                                        temp_invoice_hdr_id,
                                        process_flag,
                                        error_message,
                                        line_amount,
                                        created_by,
                                        creation_date,
                                        last_updated_by,
                                        last_update_date,
                                        temp_invoice_line_id,
                                        interco_exp_account,
                                        interco_exp_account_id,
                                        po_line_id,
                                        po_number_l,
                                        po_header_l_id,
                                        po_line_num,
                                        asset_book,
                                        asset_book_code,
                                        asset_cat_id,
                                        asset_category,
                                        track_as_asset,
                                        qty_invoiced,
                                        unit_price,
                                        DEFERRED,
                                        deferred_start_date,
                                        deferred_end_date,
                                        prorate,
                                        prorate_flag,
                                        asset_flag,
                                        deferred_flag,
                                        tax_classification_code)
                                 VALUES (l_lin_count,      --line.line_number,
                                         line.line_type,
                                         line.description,
                                         line.ship_to_location,
                                         line.dist_account, --distribution_account,
                                         line.dist_account_id,
                                         line.ship_to_location_id,
                                         line.distribution_set, --distribution_set_name,
                                         line.dist_set_id,
                                         l_invoice_id,  --temp_invoice_hdr_id,
                                         l_line_status,        --process_flag,
                                         l_lin_msg,            --error_message
                                         TO_NUMBER (line.line_amount),
                                         hdr.created_by,
                                         SYSDATE,         --hdr.creation_date,
                                         hdr.last_updated_by,
                                         SYSDATE,      --hdr.last_update_date,
                                         l_invoice_line_id,
                                         line.interco_exp_account,
                                         line.interco_exp_account_id, --attribute2
                                         line.po_line_id,
                                         line.po_number_l,
                                         line.po_header_l_id,
                                         line.po_line_num,
                                         line.asset_book,
                                         line.asset_book_code,
                                         line.asset_cat_id,
                                         line.asset_category,
                                         line.track_as_asset,
                                         line.qty_invoiced,
                                         line.unit_price,
                                         line.DEFERRED,
                                         line.deferred_start_date,
                                         line.deferred_end_date,
                                         line.prorate,
                                         line.prorate_flag,
                                         line.asset_flag,
                                         line.deferred_flag,
                                         line.tax_classification_code);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            l_line_status   := g_errored;
                            l_lin_msg       :=
                                   l_lin_msg
                                || ' Error inserting into staging lines.';
                    --NULL;
                    END;

                    IF l_line_status = g_errored
                    THEN
                        l_hdr_status   := l_line_status;
                        l_hdr_msg      :=
                               l_hdr_msg
                            || ' Error in line: '
                            || TO_CHAR (l_lin_count);
                    END IF;
                END;
            END LOOP;                                         -- END Line Loop

            l_total_line_amount   :=
                  l_total_line_amount
                + NVL (hdr.user_entered_tax, 0)
                + NVL (hdr.tax_control_amt, 0);

            -- Start of Chnage for CCR0008507

            IF     l_total_line_amount <> hdr.invoice_amount
               AND NVL (l_mtd_flag, 'N') = 'N'
            THEN
                l_hdr_status   := g_errored;
                l_hdr_msg      :=
                       l_hdr_msg
                    || ' Invoice amount does not match with total line amounts.';
            END IF;

            -- End of Change

            BEGIN
                INSERT INTO --xxdo_apinv_upload_hdrs created new tablein XXDO schema for change 1.3
                            xxdo.xxd_ap_inv_upload_hdrs (invoice_number, operating_unit, vendor_name, vendor_number, vendor_site_code, invoice_date, gl_date, invoice_amount, hdr_description, -- Added on 14-JUN-2017 for ENHC0013263
                                                                                                                                                                                               invoice_currency_code, payment_method, payment_terms, org_id, vendor_id, vendor_site_id, temp_invoice_hdr_id, unique_seq, process_flag, error_message, created_by, creation_date, last_updated_by, last_update_date, user_entered_tax, tax_control_amt, fapio_received, approver, date_sent_approver, misc_notes, chargeback, invoice_number_d, payment_ref, sample_invoice, po_header_id, fapio_flag, sample_inv_flag, invoice_type_lookup_code, po_number, pay_alone, -- Changes as per CCR0007341
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       inv_addl_info, -- Changes as per CCR0007341
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      pay_alone_flag, -- Changes as per CCR0007341
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      pay_group, -- Added for change 1.3
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 payment_hold, -- Added for change 1.3
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               request_id, -- Added for change 1.3
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           source
                                                         , -- Added as per CCR0008507
                                                           mtd_ou_flag -- Added as per CCR0008507
                                                                      )
                     VALUES (hdr.invoice_number, hdr.operating_unit, hdr.supplier, hdr.vendor_number, hdr.supplier_site, hdr.invoice_date, hdr.gl_date, hdr.invoice_amount, --TO_NUMBER(hdr.invoice_amount),
                                                                                                                                                                            hdr.hdr_description, -- Added on 14-JUN-2017 for ENHC0013263
                                                                                                                                                                                                 hdr.currency_code, hdr.payment_method, hdr.payment_terms, hdr.org_id, hdr.vendor_id, hdr.vendor_site_id, l_invoice_id, --temp_invoice_hdr_id,
                                                                                                                                                                                                                                                                                                                        hdr.unique_seq, --concurrent_request_id,
                                                                                                                                                                                                                                                                                                                                        l_hdr_status, --process_flag,
                                                                                                                                                                                                                                                                                                                                                      l_hdr_msg, --error_message
                                                                                                                                                                                                                                                                                                                                                                 hdr.created_by, SYSDATE, --hdr.creation_date,
                                                                                                                                                                                                                                                                                                                                                                                          hdr.last_updated_by, SYSDATE, --hdr.last_update_date
                                                                                                                                                                                                                                                                                                                                                                                                                        hdr.user_entered_tax, --attribute1
                                                                                                                                                                                                                                                                                                                                                                                                                                              hdr.tax_control_amt, hdr.fapio_received, hdr.approver, --attribute4
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     hdr.date_sent_approver, --attribute2
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             hdr.misc_notes, --attribute3
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             hdr.chargeback, --attribute5
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             hdr.invoice_number_d, --attribute6
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   hdr.payment_ref, --attribute7
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    hdr.sample_invoice, --attribute8
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        hdr.po_header_id, hdr.fapio_flag, hdr.sample_inv_flag, hdr.invoice_type_lookup_code, hdr.po_number, hdr.pay_alone, -- Added as per CCR0007341
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           hdr.inv_addl_info, -- Added as per CCR0007341
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              hdr.pay_alone_flag, -- Added as per CCR0007341
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  hdr.pay_group, -- Added for change 1.3
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 hdr.payment_hold, -- Added for change 1.3
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   gn_conc_request_id, -- Added for change 1.3
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       hdr.source
                             ,                      -- Added as per CCR0008507
                               l_mtd_flag);

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_hdr_status   := g_errored;
                    l_hdr_msg      :=
                           l_hdr_msg
                        || ' Error inserting staging Header. '
                        || SQLERRM;
            END;
        END LOOP;                                           -- END Header Loop

        DELETE xxdo.xxd_ap_inv_excel_upload_tbl
         WHERE     data_identifier = g_data_identifier
               AND created_by = apps.fnd_global.user_id;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            l_hdr_status   := g_errored;
            l_hdr_msg      :=
                   l_hdr_msg
                || ' Excpetion while inserting staging Header. '
                || SQLERRM;
    END;

    FUNCTION get_email_recips (p_lookup_type IN VARCHAR2)
        RETURN apps.do_mail_utils.tbl_recips
    IS
        l_def_mail_recips   apps.do_mail_utils.tbl_recips;
        l_email             VARCHAR2 (240);
        l_error             VARCHAR2 (240);
    BEGIN
        l_def_mail_recips.DELETE;
        l_email   := get_email (l_error);

        IF l_email IS NOT NULL
        THEN
            l_def_mail_recips (1)   := l_email;
        /*ELSE
           FOR c_recip IN c_recips
           LOOP
              l_def_mail_recips (l_def_mail_recips.COUNT + 1) := c_recip.meaning;
           END LOOP;*/
        END IF;

        RETURN l_def_mail_recips;
    END get_email_recips;

    PROCEDURE check_data (x_ret_code OUT VARCHAR2, x_ret_msg OUT VARCHAR2)
    IS
        CURSOR c_hdr IS
            SELECT *
              FROM xxdo.xxd_ap_inv_upload_hdrs
             WHERE     1 = 1
                   AND process_flag = g_interfaced
                   AND request_id = gn_conc_request_id; --Added for change 1.3

        --AND unique_seq = g_unique_seq;

        CURSOR c_line (p_temp_hdr_id IN NUMBER)
        IS
            SELECT *
              FROM xxdo.xxd_ap_inv_upload_lines
             WHERE 1 = 1 AND temp_invoice_hdr_id = p_temp_hdr_id;

        CURSOR c_hdr_rej (p_header_id IN NUMBER)
        IS
            SELECT reject_lookup_code, get_error_desc (reject_lookup_code) error_message
              FROM apps.ap_interface_rejections
             WHERE     parent_id = p_header_id
                   AND parent_table = 'AP_INVOICES_INTERFACE';

        CURSOR c_line_rej (p_line_id IN NUMBER)
        IS
            SELECT reject_lookup_code, get_error_desc (reject_lookup_code) error_message
              FROM apps.ap_interface_rejections
             WHERE     parent_id = p_line_id
                   AND parent_table = 'AP_INVOICE_LINES_INTERFACE';

        l_hdr_count      NUMBER := 0;
        l_line_count     NUMBER := 0;
        l_invoice_id     NUMBER := 0;
        l_hdr_boolean    BOOLEAN := NULL;
        l_line_boolean   BOOLEAN := NULL;
        l_hdr_error      VARCHAR2 (2000);
        l_line_error     VARCHAR2 (2000);
        l_status         VARCHAR2 (30);
    BEGIN
        FOR r_hdr IN c_hdr
        LOOP
            l_invoice_id    := NULL;
            l_status        := NULL;
            l_hdr_boolean   := NULL;
            l_hdr_boolean   :=
                is_invoice_created (
                    p_org_id           => r_hdr.org_id,
                    p_invoice_num      => r_hdr.invoice_number,
                    p_vendor_id        => r_hdr.vendor_id,
                    p_vendor_site_id   => r_hdr.vendor_site_id,
                    x_invoice_id       => l_invoice_id);

            IF l_hdr_boolean = TRUE
            THEN
                UPDATE xxdo.xxd_ap_inv_upload_hdrs
                   SET process_flag = g_created, invoice_id = l_invoice_id
                 WHERE temp_invoice_hdr_id = r_hdr.temp_invoice_hdr_id;
            ELSE
                l_hdr_error   := ' Interface Header Error';

                FOR r_hdr_rej IN c_hdr_rej (r_hdr.temp_invoice_hdr_id)
                LOOP
                    l_hdr_error   :=
                        l_hdr_error || '. ' || r_hdr_rej.error_message;
                END LOOP;

                UPDATE xxdo.xxd_ap_inv_upload_hdrs
                   SET process_flag = g_errored, error_message = error_message || l_hdr_error
                 WHERE temp_invoice_hdr_id = r_hdr.temp_invoice_hdr_id;
            END IF;

            FOR r_line IN c_line (r_hdr.temp_invoice_hdr_id)
            LOOP
                l_line_boolean   := NULL;
                l_line_boolean   :=
                    is_line_created (p_invoice_id    => l_invoice_id,
                                     p_line_number   => r_line.line_number);

                IF l_line_boolean = TRUE
                THEN
                    UPDATE xxdo.xxd_ap_inv_upload_lines
                       SET process_flag   = g_processed
                     WHERE temp_invoice_line_id = r_line.temp_invoice_line_id;
                ELSE
                    l_line_error   := 'Interface Line Error';

                    FOR r_line_rej
                        IN c_line_rej (r_line.temp_invoice_line_id)
                    LOOP
                        l_line_error   :=
                            l_line_error || '. ' || r_line_rej.error_message;
                    END LOOP;

                    UPDATE xxdo.xxd_ap_inv_upload_lines
                       SET process_flag = g_errored, error_message = error_message || l_line_error
                     WHERE temp_invoice_line_id = r_line.temp_invoice_line_id;

                    UPDATE xxdo.xxd_ap_inv_upload_hdrs
                       SET process_flag = g_errored, error_message = error_message || ' Error in Line:' || r_line.line_number
                     WHERE temp_invoice_hdr_id = r_hdr.temp_invoice_hdr_id;
                END IF;
            END LOOP;
        END LOOP;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_msg    := x_ret_msg || ' Error in check_data: ' || SQLERRM;
            x_ret_code   := '2';
    --apps.fnd_file.put_line(apps.fnd_file.log,SQLERRM);
    END check_data;

    PROCEDURE email_out (x_ret_code OUT VARCHAR2, x_ret_msg OUT VARCHAR2)
    IS
        l_out_line          VARCHAR2 (10000);
        l_counter           NUMBER := 0;
        l_ret_val           NUMBER := 0;
        l_def_mail_recips   apps.do_mail_utils.tbl_recips;
        l_sqlerrm           VARCHAR2 (4000);

        CURSOR c_hdr IS
            SELECT invoice_number, operating_unit, vendor_name,
                   vendor_number, vendor_site_code, TO_CHAR (invoice_date, 'MM/DD/YYYY') invoice_date,
                   invoice_amount, invoice_currency_code, hdr_description,
                   -- Added on 14-JUN-2017 for ENHC0013263
                   user_entered_tax, tax_control_amt, fapio_received,
                   approver, date_sent_approver, misc_notes,
                   po_number, chargeback, invoice_number_d,
                   payment_ref, sample_invoice, temp_invoice_hdr_id,
                   unique_seq, fapio_flag, sample_inv_flag,
                   source, mtd_ou_flag,             -- Added as per CCR0008507
                                        process_flag,
                   error_message, TO_CHAR (gl_date, 'MM/DD/YYYY') gl_date, DECODE (invoice_type_lookup_code,  'STANDARD', 'Standard Invoice',  'CREDIT', 'Credit Memo') invoice_type_lookup_code,
                   pay_alone,                       -- Added as per CCR0007341
                              pay_alone_flag,       -- Added as per CCR0007341
                                              inv_addl_info -- Added as per CCR0007341
              FROM xxdo.xxd_ap_inv_upload_hdrs
             WHERE 1 = 1 AND request_id = gn_conc_request_id; --Added for change 1.3

        --AND unique_seq = g_unique_seq;

        CURSOR c_line (p_invoice_id IN NUMBER)
        IS
              SELECT line_number, line_type, line_description,
                     line_amount, ship_to_location_code, distribution_account,
                     distribution_set, po_number_l, po_line_num,
                     qty_invoiced, unit_price, DEFERRED,
                     TO_CHAR (deferred_start_date, 'MM/DD/YYYY') deferred_start_date, TO_CHAR (deferred_end_date, 'MM/DD/YYYY') deferred_end_date, prorate,
                     tax_classification_code, track_as_asset, temp_invoice_hdr_id,
                     temp_invoice_line_id, asset_category, asset_book,
                     process_flag, error_message, interco_exp_account,
                     prorate_flag, asset_flag, deferred_flag
                FROM xxdo.xxd_ap_inv_upload_lines
               WHERE 1 = 1 AND temp_invoice_hdr_id = p_invoice_id
            ORDER BY line_number;

        ex_no_recips        EXCEPTION;
        ex_validation_err   EXCEPTION;
        ex_no_data_found    EXCEPTION;
        lv_org_code         VARCHAR2 (240);
        ln_cnt              NUMBER := 1;
        l_hdr_status        VARCHAR2 (30);
        l_line_status       VARCHAR2 (30);
    BEGIN
        BEGIN
            SELECT NAME
              INTO lv_org_code
              FROM hr_operating_units
             WHERE organization_id = apps.fnd_global.org_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_org_code   := NULL;
        END;

        --apps.fnd_file.put_line(apps.fnd_file.log,' Email Out 2');
        l_def_mail_recips   := get_email_recips (g_dist_list_name);
        apps.do_mail_utils.send_mail_header (apps.fnd_profile.VALUE ('DO_DEF_ALERT_SENDER'), l_def_mail_recips, 'AP Invoice Excel Upload - ' || TO_CHAR (SYSDATE, 'MM/DD/YYYY HH24:MI:SS')
                                             , l_ret_val);
        apps.do_mail_utils.send_mail_line (
            'Content-Type: multipart/mixed; boundary=boundarystring',
            l_ret_val);
        apps.do_mail_utils.send_mail_line ('--boundarystring', l_ret_val);
        apps.do_mail_utils.send_mail_line ('Content-Type: text/plain',
                                           l_ret_val);
        apps.do_mail_utils.send_mail_line ('', l_ret_val);
        apps.do_mail_utils.send_mail_line ('Organization - ' || lv_org_code,
                                           l_ret_val);
        apps.do_mail_utils.send_mail_line ('--boundarystring', l_ret_val);
        apps.do_mail_utils.send_mail_line ('Content-Type: text/xls',
                                           l_ret_val);
        apps.do_mail_utils.send_mail_line (
            'Content-Disposition: attachment; filename="AP Invoice excel upload.xls"',
            l_ret_val);
        apps.do_mail_utils.send_mail_line ('', l_ret_val);
        --apps.fnd_file.put_line(apps.fnd_file.log,' Email Out 3');
        apps.do_mail_utils.send_mail_line (
               'PO Number Header Level '
            || CHR (9)
            || 'Invoice Number '
            || CHR (9)
            || 'Operating Unit '
            || CHR (9)
            || 'Invoice Type'
            || CHR (9)
            || 'Vendor Name '
            || CHR (9)
            || 'Vendor Number '
            || CHR (9)
            || 'Vendor Site '
            || CHR (9)
            || 'Invoice Date '
            || CHR (9)
            || 'GL Date '
            || CHR (9)
            || 'Invoice Amount'
            || CHR (9)
            || 'Currency Code'
            || CHR (9)
            ||                         -- Added on 14-JUN-2017 for ENHC0013263
               'Invoice Description'
            || CHR (9)
            ||                         -- Added on 14-JUN-2017 for ENHC0013263
               'Vendor Charged Tax'
            || CHR (9)
            ||                                                    --attribute1
               'Tax Control Amount'
            || CHR (9)
            || 'Approver'
            || CHR (9)
            ||                                                    --attribute4
               'Date Sent to Approver'
            || CHR (9)
            || 'Misc Notes'
            || CHR (9)
            ||                                                    --attribute3
               'Chargeback?'
            || CHR (9)
            ||                                                    --attribute5
               'Invoice_Number'
            || CHR (9)
            ||                                                    --attribute6
               'Payment Ref#'
            || CHR (9)
            ||                                                    --attribute7
               'Sample Invoice?'
            || CHR (9)
            ||                                                    --attribute8
               'FAPIO Received'
            || CHR (9)
            || 'Pay Alone'
            || CHR (9)
            ||                                      -- added as per CCR0007341
               'Inv Addl info'
            || CHR (9)
            ||                                      -- added as per CCR0007341
               'Invoice Source'                     -- Added as per CCR0008507
            || CHR (9)
            || 'Line Type'
            || CHR (9)
            || 'Line Number'
            || CHR (9)
            || 'Description'
            || CHR (9)
            || 'Line Amount'
            || CHR (9)
            || 'Distribution Account'
            || CHR (9)
            || 'Ship To location'
            || CHR (9)
            || 'Distribution set'
            || CHR (9)
            || 'PO Number Line Level'
            || CHR (9)
            || 'PO Line Number'
            || CHR (9)
            || 'Qty Invoiced'
            || CHR (9)
            || 'Unit Price'
            || CHR (9)
            || 'Tax Calssification Code'
            || CHR (9)
            || 'Interco Expense Account'
            || CHR (9)
            ||                                                    --attribute2
               'Deferred Option'
            || CHR (9)
            || 'Deferred Start Date'
            || CHR (9)
            || 'Deferred End Date'
            || CHR (9)
            || 'Prorate Across Items'
            || CHR (9)
            || 'Track as Asset'
            || CHR (9)
            || 'Asset Category'
            || CHR (9)
            || 'Asset Book'
            || CHR (9)
            || 'Header Status'
            || CHR (9)
            || 'Header message'
            || CHR (9)
            || 'Line Status'
            || CHR (9)
            || 'Line message',
            l_ret_val);

        --apps.fnd_file.put_line(apps.fnd_file.log,' Email Out 4');
        FOR r_hdr IN c_hdr
        LOOP
            l_hdr_status   := NULL;

            IF r_hdr.process_flag = g_new
            THEN
                l_hdr_status   := 'New';
            ELSIF r_hdr.process_flag = g_errored
            THEN
                l_hdr_status   := 'Error';
            ELSIF r_hdr.process_flag = g_validated
            THEN
                l_hdr_status   := 'No Invoice Header Error';
            ELSIF r_hdr.process_flag = g_processed
            THEN
                l_hdr_status   := 'Invoice Processed';
            ELSIF r_hdr.process_flag = g_created
            THEN
                l_hdr_status   := 'Invoice Created';
            ELSIF r_hdr.process_flag = g_interfaced
            THEN
                l_hdr_status   := 'Invoice Interfaced';
            ELSE
                l_hdr_status   := 'Other';
            END IF;

            FOR r_line IN c_line (r_hdr.temp_invoice_hdr_id)
            LOOP
                l_line_status   := NULL;

                IF r_line.process_flag = g_new
                THEN
                    l_line_status   := 'New';
                ELSIF r_line.process_flag = g_errored
                THEN
                    l_line_status   := 'Error';
                ELSIF r_line.process_flag = g_validated
                THEN
                    l_line_status   := 'No Line Error';
                ELSIF r_line.process_flag = g_processed
                THEN
                    l_line_status   := 'Processed';
                ELSIF r_line.process_flag = g_interfaced
                THEN
                    l_line_status   := 'Interfaced';
                ELSE
                    l_line_status   := 'Other';
                END IF;

                l_counter       := l_counter + 1;
                l_out_line      := NULL;
                l_out_line      :=
                       NVL (r_hdr.po_number, 'NULL')
                    || CHR (9)
                    || NVL (r_hdr.invoice_number, 'NULL')
                    || CHR (9)
                    || NVL (r_hdr.operating_unit, 'NULL')
                    || CHR (9)
                    || NVL (r_hdr.invoice_type_lookup_code, 'NULL')
                    || CHR (9)
                    || NVL (r_hdr.vendor_name, 'NULL')
                    || CHR (9)
                    || NVL (r_hdr.vendor_number, 'NULL')
                    || CHR (9)
                    || NVL (r_hdr.vendor_site_code, 'NULL')
                    || CHR (9)
                    || NVL (r_hdr.invoice_date, 'NULL')
                    || CHR (9)
                    || NVL (r_hdr.gl_date, 'NULL')
                    || CHR (9)
                    || NVL (TO_CHAR (r_hdr.invoice_amount), 'NULL')
                    || CHR (9)
                    || NVL (r_hdr.invoice_currency_code, 'NULL')
                    || CHR (9)
                    ||                 -- Added on 14-JUN-2017 for ENHC0013263
                       NVL (r_hdr.hdr_description, 'NULL')
                    || CHR (9)
                    ||                 -- Added on 14-JUN-2017 for ENHC0013263
                       NVL (r_hdr.user_entered_tax, 'NULL')
                    || CHR (9)
                    ||                                            --attribute1
                       NVL (TO_CHAR (r_hdr.tax_control_amt), 'NULL')
                    || CHR (9)
                    || NVL (r_hdr.approver, 'NULL')
                    || CHR (9)
                    ||                                            --attribute4
                       NVL (r_hdr.date_sent_approver, 'NULL')
                    || CHR (9)
                    ||                                            --attribute2
                       NVL (r_hdr.misc_notes, 'NULL')
                    || CHR (9)
                    ||                                            --attribute3
                       NVL (r_hdr.chargeback, 'NULL')
                    || CHR (9)
                    ||                                            --attribute5
                       NVL (r_hdr.invoice_number_d, 'NULL')
                    || CHR (9)
                    ||                                            --attribute6
                       NVL (r_hdr.payment_ref, 'NULL')
                    || CHR (9)
                    ||                                            --attribute7
                       NVL (r_hdr.sample_invoice, 'NULL')
                    || CHR (9)
                    ||                                            --attribute8
                       NVL (TO_CHAR (r_hdr.fapio_received), 'NULL')
                    || CHR (9)
                    ||                                           --attribute10
                       NVL (r_hdr.pay_alone, 'NULL')
                    || CHR (9)
                    ||                -- Added as per CCR0007341 (Attribute11)
                       NVL (r_hdr.inv_addl_info, 'NULL')
                    || CHR (9)
                    ||                              -- Added as per CCR0007341
                       NVL (r_hdr.source, 'NULL')   -- Added as per CCR0008507
                    || CHR (9)
                    || NVL (r_line.line_type, 'NULL')
                    || CHR (9)
                    || NVL (TO_CHAR (r_line.line_number), 'NULL')
                    || CHR (9)
                    || NVL (r_line.line_description, 'NULL')
                    || CHR (9)
                    || NVL (TO_CHAR (r_line.line_amount), 'NULL')
                    || CHR (9)
                    || NVL (r_line.distribution_account, 'NULL')
                    || CHR (9)
                    || NVL (r_line.ship_to_location_code, 'NULL')
                    || CHR (9)
                    || NVL (r_line.distribution_set, 'NULL')
                    || CHR (9)
                    || NVL (r_line.po_number_l, 'NULL')
                    || CHR (9)
                    || NVL (TO_CHAR (r_line.po_line_num), 'NULL')
                    || CHR (9)
                    || NVL (TO_CHAR (r_line.qty_invoiced), 'NULL')
                    || CHR (9)
                    || NVL (TO_CHAR (r_line.unit_price), 'NULL')
                    || CHR (9)
                    || NVL (r_line.tax_classification_code, 'NULL')
                    || CHR (9)
                    || NVL (r_line.interco_exp_account, 'NULL')
                    || CHR (9)
                    || NVL (r_line.DEFERRED, 'NULL')
                    || CHR (9)
                    || NVL (r_line.deferred_start_date, 'NULL')
                    || CHR (9)
                    || NVL (r_line.deferred_end_date, 'NULL')
                    || CHR (9)
                    || NVL (r_line.prorate, 'NULL')
                    || CHR (9)
                    || NVL (r_line.track_as_asset, 'NULL')
                    || CHR (9)
                    || NVL (r_line.asset_category, 'NULL')
                    || CHR (9)
                    || NVL (r_line.asset_book, 'NULL')
                    || CHR (9)
                    || NVL (l_hdr_status, 'NULL')
                    || CHR (9)
                    || NVL (SUBSTR (r_hdr.error_message, 1, 200), 'NULL')
                    || CHR (9)
                    || NVL (l_line_status, 'NULL')
                    || CHR (9)
                    || NVL (r_line.error_message, 'NULL');
                apps.do_mail_utils.send_mail_line (l_out_line, l_ret_val);
                l_counter       := l_counter + 1;
            END LOOP;
        END LOOP;                                                --header loop

        --apps.fnd_file.put_line(apps.fnd_file.log,' Email Out 7');
        apps.do_mail_utils.send_mail_close (l_ret_val);
        ln_cnt              := ln_cnt + 1;

        IF l_counter = 0
        THEN
            RAISE ex_no_data_found;
        END IF;
    EXCEPTION
        WHEN ex_no_data_found
        THEN
            apps.do_mail_utils.send_mail_header (apps.fnd_profile.VALUE ('DO_DEF_ALERT_SENDER'), l_def_mail_recips, 'AP Invoice Excel Upload - ' || TO_CHAR (SYSDATE, 'MM/DD/YYYY HH24:MI:SS')
                                                 , l_ret_val);
            apps.do_mail_utils.send_mail_line (
                'Content-Type: multipart/mixed; boundary=boundarystring',
                l_ret_val);
            apps.do_mail_utils.send_mail_line ('--boundarystring', l_ret_val);
            apps.do_mail_utils.send_mail_line ('Content-Type: text/plain',
                                               l_ret_val);
            apps.do_mail_utils.send_mail_line ('', l_ret_val);
            apps.do_mail_utils.send_mail_line (' ', l_ret_val);
            apps.do_mail_utils.send_mail_line (
                '*******No Eligible Records for this Request*********.',
                l_ret_val);
            apps.do_mail_utils.send_mail_line (' ', l_ret_val);
            apps.do_mail_utils.send_mail_line (
                'Unique Sequnce -' || g_unique_seq,
                l_ret_val);
            apps.do_mail_utils.send_mail_line (
                'Organization Code -' || lv_org_code,
                l_ret_val);
            apps.do_mail_utils.send_mail_close (l_ret_val);
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                '-----------------------------------------------------------------------');
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                '*************** No Eligible Records at this Request *******************');
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                '-----------------------------------------------------------------------');
        WHEN ex_validation_err
        THEN
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                '-----------------------------------------------------------------------');
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                '*************** Invalid Email format *******************');
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                '-----------------------------------------------------------------------');
            x_ret_code   := 1;
        WHEN OTHERS
        THEN
            l_sqlerrm   := SUBSTR (SQLERRM, 1, 200);
            apps.do_mail_utils.send_mail_close (l_ret_val);
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                '-----------------------------------------------------------------------');
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                   '******** Exception Occured while submitting the Request'
                || SQLERRM);
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                '----------------------------------------------------------------------------');
            COMMIT;
    END email_out;

    PROCEDURE update_payment_hold (x_ret_code   OUT NUMBER,
                                   x_ret_msg    OUT VARCHAR2)
    IS
        CURSOR c_hdr IS
            SELECT *
              FROM xxdo.xxd_ap_inv_upload_hdrs
             WHERE     1 = 1
                   AND process_flag = g_created
                   AND request_id = gn_conc_request_id;

        l_invoice_id    NUMBER := 0;
        l_hdr_boolean   BOOLEAN := NULL;
        l_status        VARCHAR2 (30);
    BEGIN
        FOR r_hdr IN c_hdr
        LOOP
            IF r_hdr.payment_hold = 'Y'
            THEN
                BEGIN
                    /* As per note 2550824.1 there is no api to update hold_flag ap_payment_schedules_all,updating it directly*/
                    UPDATE ap_payment_schedules_all
                       SET hold_flag   = 'Y'
                     WHERE invoice_id = r_hdr.invoice_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        x_ret_msg    :=
                               x_ret_msg
                            || ' Error while updating payment hold: '
                            || SQLERRM;
                        x_ret_code   := '2';
                END;

                COMMIT;
            END IF;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_msg    :=
                x_ret_msg || ' Error in updated_payment_hold: ' || SQLERRM;
            x_ret_code   := '2';
    END update_payment_hold;

    PROCEDURE main (pv_retcode OUT NUMBER, pv_errproc OUT VARCHAR2) --(p_validate   IN    VARCHAR2)
    IS
        ex_load_interface    EXCEPTION;
        ex_create_invoices   EXCEPTION;
        ex_email_out         EXCEPTION;
        ex_check_data        EXCEPTION;
        ex_insert_stg        EXCEPTION;
        l_ret_code           VARCHAR2 (1);
        l_ret_msg            VARCHAR2 (4000);
        lc_err_message       VARCHAR2 (100);
    BEGIN
        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'Inserting into Staging tables..');
        insert_stg (x_ret_code => l_ret_code, x_ret_msg => l_ret_msg);

        IF l_ret_code = '2'
        THEN
            RAISE ex_insert_stg;
        END IF;

        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'Loading into interface tables..');
        load_interface (x_ret_code => l_ret_code, x_ret_msg => l_ret_msg);

        IF l_ret_code = '2'
        THEN
            RAISE ex_load_interface;
        END IF;

        apps.fnd_file.put_line (apps.fnd_file.LOG, 'Creating Invoices..');
        create_invoices (x_ret_code => l_ret_code, x_ret_msg => l_ret_msg);

        IF l_ret_code = '2'
        THEN
            RAISE ex_create_invoices;
        END IF;

        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'Checking Invoices data..');
        check_data (x_ret_code => l_ret_code, x_ret_msg => l_ret_msg);

        IF l_ret_code = '2'
        THEN
            RAISE ex_create_invoices;
        END IF;

        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
            'Updating hold_flag in ap_payment_schedules_all when payment_hold is Yes');
        update_payment_hold (x_ret_code => l_ret_code, x_ret_msg => l_ret_msg);

        IF l_ret_code = '2'
        THEN
            RAISE ex_create_invoices;
        END IF;

        --apps.fnd_file.put_line(apps.fnd_file.log,'Mailing Output..');
        email_out (x_ret_code => l_ret_code, x_ret_msg => l_ret_msg);

        IF l_ret_code = '2'
        THEN
            RAISE ex_email_out;
        END IF;

        --  apps.fnd_file.put_line(apps.fnd_file.log,'Clearing Interface Tables..');
        clear_int_tables;
    EXCEPTION
        WHEN ex_insert_stg
        THEN
            l_ret_msg        := 'Exception occurred while Loading staging table';
            fnd_message.set_name ('XXDO', 'XXD_ORDER_UPLOAD_WEBADI_MSG');
            fnd_message.set_token ('ERROR_MESSAGE', l_ret_msg);
            lc_err_message   := fnd_message.get ();
            raise_application_error (-20032, lc_err_message);
        WHEN ex_load_interface
        THEN
            l_ret_msg        := 'Exception occurred while Loading Interface';
            fnd_message.set_name ('XXDO', 'XXD_ORDER_UPLOAD_WEBADI_MSG');
            fnd_message.set_token ('ERROR_MESSAGE', l_ret_msg);
            lc_err_message   := fnd_message.get ();
            raise_application_error (-20032, lc_err_message);
        WHEN ex_create_invoices
        THEN
            l_ret_msg        := 'Exception occurred in the Creating Interface';
            fnd_message.set_name ('XXDO', 'XXD_ORDER_UPLOAD_WEBADI_MSG');
            fnd_message.set_token ('ERROR_MESSAGE', l_ret_msg);
            lc_err_message   := fnd_message.get ();
            raise_application_error (-20032, lc_err_message);
        WHEN ex_check_data
        THEN
            l_ret_msg        := 'Exception occurred in the Checking the Data';
            fnd_message.set_name ('XXDO', 'XXD_ORDER_UPLOAD_WEBADI_MSG');
            fnd_message.set_token ('ERROR_MESSAGE', l_ret_msg);
            lc_err_message   := fnd_message.get ();
            raise_application_error (-20032, lc_err_message);
        WHEN ex_email_out
        THEN
            l_ret_msg        := 'Exception occurred in the emailing the Data';
            fnd_message.set_name ('XXDO', 'XXD_ORDER_UPLOAD_WEBADI_MSG');
            fnd_message.set_token ('ERROR_MESSAGE', l_ret_msg);
            lc_err_message   := fnd_message.get ();
            raise_application_error (-20032, lc_err_message);
        WHEN OTHERS
        THEN
            l_ret_msg        := 'When others Exception occurred in the Process';
            fnd_message.set_name ('XXDO', 'XXD_ORDER_UPLOAD_WEBADI_MSG');
            fnd_message.set_token ('ERROR_MESSAGE', l_ret_msg);
            lc_err_message   := fnd_message.get ();
            raise_application_error (-20032, lc_err_message);
    END main;
END xxdo_apinv_upload_pkg;
/
