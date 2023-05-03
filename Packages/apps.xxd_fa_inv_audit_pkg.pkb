--
-- XXD_FA_INV_AUDIT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:30:38 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_FA_INV_AUDIT_PKG"
AS
    /************************************************************************************************
    * Package         : XXD_FA_INV_AUDIT_PKG
    * Description     : This package is used to get Documents by Entities
    * Notes           : 1. DATA Template XML Query and PKG Query always should maintain SYNC while changes.
    *                 : 2. Pre-fix should maintain SYNC in upload function and calling function.
    * Modification    :
    *-----------------------------------------------------------------------------------------------
    * Date         Version#      Name                       Description
    *-----------------------------------------------------------------------------------------------
    * 04-APR-2018  1.0           Aravind Kannuri           Initial Version for CCR0007106
    * 22-JUN-2018  1.1           Aravind Kannuri           Added New Fields
    ************************************************************************************************/

    --To fetch Invoices to upload
    FUNCTION upload_inv_docs
        RETURN BOOLEAN
    IS
        CURSOR get_invoice_dtls_c IS
              SELECT DISTINCT
                     aia.invoice_id,
                     NVL (aia.invoice_num, fai.invoice_number) invoice_num, -- Added for NEW columns
                     get_asset_inv_id (p_ap_invoice_id => aia.invoice_id, p_asset_inv_id => fai.invoice_id, p_asset_inv_num => fai.invoice_number
                                       , p_po_vendor_id => fai.po_vendor_id) asset_invoice_id
                --   'Invoices_'||aia.invoice_num||'_'|| fl.file_name  doc_file_name
                FROM fa_additions fad, fa_books fb, fa_book_controls fbc,
                     fa_categories fc, fa_category_books fcb, fa_asset_invoices fai,
                     fa_distribution_history fdh, fa_locations fl, ap_invoices_all aia,
                     ap_suppliers aps, gl_code_combinations gcc
               WHERE     fad.asset_id = fb.asset_id
                     AND fad.asset_category_id = fc.category_id
                     AND fc.category_id = fcb.category_id
                     AND fcb.book_type_code = fb.book_type_code
                     AND fb.book_type_code = fbc.book_type_code
                     AND fad.asset_id = fai.asset_id(+)
                     AND fai.invoice_id = aia.invoice_id(+)
                     AND aia.vendor_id = aps.vendor_id(+)
                     AND fdh.code_combination_id = gcc.code_combination_id
                     AND fad.asset_id = fdh.asset_id
                     AND fdh.location_id = fl.location_id
                     AND fdh.book_type_code = fb.book_type_code
                     AND fb.book_type_code =
                         NVL (p_asset_book_name, fb.book_type_code)
                     AND NVL (gcc.segment5, 'X') =
                         NVL (p_cost_center, NVL (gcc.segment5, 'X'))
                     AND TRUNC (fb.date_placed_in_service) >=
                         (SELECT gps.start_date
                            FROM gl_period_statuses gps
                           WHERE     gps.period_name = p_period_from
                                 AND gps.set_of_books_id = fbc.set_of_books_id
                                 AND gps.application_id = 101)
                     AND TRUNC (fb.date_placed_in_service) <=
                         (SELECT gps.end_date
                            FROM gl_period_statuses gps
                           WHERE     gps.period_name = p_period_to
                                 AND gps.set_of_books_id = fbc.set_of_books_id
                                 AND gps.application_id = 101)
                     AND fb.transaction_header_id_out IS NULL
                     AND fdh.transaction_header_id_out IS NULL
                     AND fad.asset_type IN ('CAPITALIZED', 'CIP')
                     AND fad.asset_number =
                         NVL (p_asset_number, fad.asset_number)
                     AND DECODE (fad.asset_type,
                                 'CAPITALIZED', fcb.asset_cost_acct,
                                 'CIP', fcb.cip_cost_acct) BETWEEN p_asset_account_from
                                                               AND NVL (
                                                                       p_asset_account_to,
                                                                       p_asset_account_from)
                     AND fl.segment2 = NVL (p_asset_location, fl.segment2)
            ORDER BY aia.invoice_id;

        get_invoice_dtls_rec   get_invoice_dtls_c%ROWTYPE;
        ln_count               NUMBER := 0;
        lv_upld_result         VARCHAR2 (50) := 'S';
        lv_doc_prefix          VARCHAR2 (100) := NULL;
    BEGIN
        --Print Parameters in LOG
        fnd_file.put_line (fnd_file.LOG, 'After Report Trigger Starts :');
        fnd_file.put_line (fnd_file.LOG,
                           'p_entity_name => ' || p_entity_name);
        fnd_file.put_line (fnd_file.LOG,
                           'p_asset_book_name => ' || p_asset_book_name);
        fnd_file.put_line (fnd_file.LOG,
                           'p_user_file_path => ' || p_user_file_path);

        FOR get_invoice_dtls_rec IN get_invoice_dtls_c
        LOOP
            ln_count   := get_invoice_dtls_c%ROWCOUNT;

            IF get_invoice_dtls_rec.asset_invoice_id IS NOT NULL
            THEN
                -- Prefix should be same here and in calling function 'GET_DOC_FILE_PATH'(Data Template)
                lv_doc_prefix   :=
                       REPLACE (fnd_global.user_name, '.', '_')
                    || '_'
                    || get_invoice_dtls_rec.invoice_num
                    || '_';

                --Calling generic procedure to upload Asset Invoice documents in 'XXD_FND_DOCUMENTS'
                --lv_doc_prefix : Prefix of Document file to store in directory
                lv_upld_result   :=
                    xxd_fnd_doc_files_pkg.get_doc_files (get_invoice_dtls_rec.asset_invoice_id, 'AP_INVOICES', --Entity Name
                                                                                                               'XXD_FND_DOCUMENTS'
                                                         ,   -- Directory Name
                                                           lv_doc_prefix --'Invoices_'
                                                                        );
            END IF;
        END LOOP;

        fnd_file.put_line (
            fnd_file.LOG,
            'Uploaded Invoice Documents count => ' || ln_count);

        IF lv_upld_result = 'S'
        THEN
            RETURN TRUE;
        ELSE
            RETURN FALSE;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Others Exception in UPLOAD_INV_DOCS: ' || SQLERRM);
            RETURN FALSE;
    END upload_inv_docs;

    --To get and display document file path in report
    FUNCTION get_doc_file_path (p_pk1_value_id IN NUMBER, p_entity_name IN fnd_attached_documents.entity_name%TYPE, p_user_file_path IN VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_doc_file_name   dba_directories.directory_path%TYPE := NULL;
    BEGIN
        --p_user_file_path should be '\\corporate.deckers.com\Sites\Goleta\Common\Deckers Enhancement\Invoices\'
        IF p_user_file_path IS NOT NULL AND p_pk1_value_id IS NOT NULL
        THEN
            BEGIN
                  SELECT p_user_file_path || fl.file_name
                    INTO lv_doc_file_name
                    FROM fnd_attached_documents fad, fnd_documents fd, fnd_lobs fl,
                         fnd_document_datatypes fdd
                   WHERE     fad.document_id = fd.document_id
                         AND fd.media_id = fl.file_id
                         AND fd.datatype_id = fdd.datatype_id
                         AND fdd.NAME = 'FILE'
                         AND fad.entity_name =
                             NVL (p_entity_name, 'AP_INVOICES')
                         AND fad.pk1_value = TO_CHAR (p_pk1_value_id)
                         AND fad.seq_num =
                             (SELECT MAX (seq_num)
                                FROM apps.fnd_attached_documents fad1
                               WHERE fad1.pk1_value = TO_CHAR (p_pk1_value_id))
                         AND fdd.LANGUAGE = USERENV ('LANG')
                         AND fl.LANGUAGE = USERENV ('LANG')
                ORDER BY fad.pk1_value;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_doc_file_name   := NULL;
            END;
        ELSE
            lv_doc_file_name   := NULL;
            fnd_file.put_line (
                fnd_file.LOG,
                'get_doc_file_path function parameters is NULL ');
        END IF;

        RETURN lv_doc_file_name;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Others Exception in UPLOAD_INV_DOCS: ' || SQLERRM);
            RETURN NULL;
    END get_doc_file_path;

    --To get asset_invoice_id
    FUNCTION get_asset_inv_id (p_ap_invoice_id IN NUMBER, p_asset_inv_id IN NUMBER, p_asset_inv_num IN VARCHAR2
                               , p_po_vendor_id IN NUMBER)
        RETURN NUMBER
    IS
        ln_asset_inv_id   ap_invoices_all.invoice_id%TYPE := NULL;
    BEGIN
        IF p_ap_invoice_id IS NOT NULL
        THEN
            ln_asset_inv_id   := p_ap_invoice_id;
        ELSIF     p_asset_inv_id IS NULL
              AND p_asset_inv_num IS NOT NULL
              AND p_po_vendor_id IS NOT NULL
        THEN
            SELECT invoice_id
              INTO ln_asset_inv_id
              FROM ap_invoices_all
             WHERE     invoice_num = p_asset_inv_num
                   AND vendor_id = p_po_vendor_id;
        ELSE
            ln_asset_inv_id   := p_ap_invoice_id;
        END IF;

        RETURN ln_asset_inv_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Others Exception in GET_ASSET_INV_ID: ' || SQLERRM);
            RETURN NULL;
    END get_asset_inv_id;

    --To get Asset Capitalized Amount
    FUNCTION get_asset_cap_amt (p_asset_type IN VARCHAR2, p_asset_id IN NUMBER, p_asset_inv_num IN VARCHAR2)
        RETURN NUMBER
    IS
        ln_asset_cap_amt   fa_asset_invoices.fixed_assets_cost%TYPE := NULL;
    BEGIN
        IF p_asset_type = 'CAPITALIZED'
        THEN
            IF p_asset_inv_num IS NOT NULL
            THEN
                  SELECT SUM (fixed_assets_cost)
                    INTO ln_asset_cap_amt
                    FROM fa_asset_invoices
                   WHERE     asset_id = p_asset_id
                         AND invoice_number = p_asset_inv_num
                         AND date_ineffective IS NULL
                GROUP BY asset_id, invoice_number;
            ELSE
                  SELECT SUM (fixed_assets_cost)
                    INTO ln_asset_cap_amt
                    FROM fa_asset_invoices
                   WHERE     asset_id = p_asset_id
                         AND invoice_number IS NULL
                         AND date_ineffective IS NULL
                GROUP BY asset_id;
            END IF;
        ELSE                                            --p_asset_type = 'CIP'
            ln_asset_cap_amt   := NULL;
        END IF;

        RETURN ln_asset_cap_amt;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Others Exception in GET_ASSET_CAP_AMT: ' || SQLERRM);
            RETURN NULL;
    END get_asset_cap_amt;


    --To get Other Asset Amount for Invoice
    FUNCTION get_oth_asset_amt (p_asset_type IN VARCHAR2, p_asset_id IN NUMBER, p_asset_inv_num IN VARCHAR2)
        RETURN NUMBER
    IS
        CURSOR c_get_oth_asset_id IS
              SELECT asset_id
                FROM fa_asset_invoices fai
               WHERE     invoice_number = p_asset_inv_num
                     AND date_ineffective IS NULL
                     AND asset_id NOT IN
                             (SELECT asset_id
                                FROM fa_asset_invoices fai1
                               WHERE     fai.asset_id = fai1.asset_id
                                     AND asset_id = p_asset_id)
            GROUP BY asset_id;

        ln_oth_asset_id      fa_asset_invoices.asset_id%TYPE;
        ln_other_asset_amt   fa_asset_invoices.fixed_assets_cost%TYPE := NULL;
    --lnu_oth_asset_id     c_get_oth_asset_id%ROWTYPE;

    BEGIN
        IF p_asset_type = 'CAPITALIZED'
        THEN
            IF p_asset_inv_num IS NOT NULL
            THEN
                OPEN c_get_oth_asset_id;

                FETCH c_get_oth_asset_id INTO ln_oth_asset_id;

                CLOSE c_get_oth_asset_id;

                IF ln_oth_asset_id IS NOT NULL
                THEN
                      SELECT SUM (fixed_assets_cost)
                        INTO ln_other_asset_amt
                        FROM fa_asset_invoices
                       WHERE     asset_id = ln_oth_asset_id
                             AND invoice_number = p_asset_inv_num
                             AND date_ineffective IS NULL
                    GROUP BY asset_id, invoice_number;
                ELSE
                    ln_other_asset_amt   := NULL;
                END IF;
            ELSE
                ln_other_asset_amt   := NULL;
            END IF;
        ELSE                                            --p_asset_type = 'CIP'
            ln_other_asset_amt   := NULL;
        END IF;

        RETURN ln_other_asset_amt;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Others Exception in GET_OTH_ASSET_AMT: ' || SQLERRM);
            RETURN NULL;
    END get_oth_asset_amt;
END xxd_fa_inv_audit_pkg;
/
