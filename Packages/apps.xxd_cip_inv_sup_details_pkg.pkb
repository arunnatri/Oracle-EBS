--
-- XXD_CIP_INV_SUP_DETAILS_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:31:07 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS.xxd_cip_inv_sup_details_pkg
AS
    /*******************************************************************************
 * Program Name : XXD_CIP_INV_SUP_DETAILS_PKG
 * Language  : PL/SQL
 * Description  : This package will be used for the view XXD_EXP_NEW_TRANSFER_V
 * History :
 *
 *   WHO    Version  when   Desc
 * --------------------------------------------------------------------------
 * BT Technology Team   1.0    21/Jan/2015  Interface Prog
 * --------------------------------------------------------------------------- */


    FUNCTION get_invoice_num (P_transaction_source   VARCHAR2,
                              p_invoice_id           NUMBER)
        RETURN VARCHAR2
    IS
        --Local Variables
        lv_invoice_id    VARCHAR2 (30);
        lv_invoice_num   VARCHAR2 (30);
        lv_transaction   VARCHAR2 (20);
    BEGIN
        lv_invoice_id    := p_invoice_id;
        lv_transaction   := P_transaction_source;

        IF lv_transaction IN
               ('AP INVOICE', 'INTERPROJECT_AP_INVOICES', 'AP VARIANCE',
                'AP NRTAX', 'AP DISCOUNTS', 'AP EXPENSE',
                'AP ERV', 'CSE_IPV_ADJUSTMENT', 'CSE_IPV_ADJUSTMENT_DEPR')
        THEN
            SELECT invoice_num
              INTO lv_invoice_num
              FROM ap_invoices_all aia
             WHERE aia.invoice_id = lv_invoice_id;
        END IF;

        RETURN lv_invoice_num;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_invoice_num;

    ------------------------------------------------------------------------------------------------------------------------------------
    FUNCTION get_invoice_date (P_transaction_source   VARCHAR2,
                               p_invoice_id           NUMBER)
        RETURN VARCHAR2
    IS
        --Local Variables
        lv_invoice_id     VARCHAR2 (30);
        lv_invoice_date   VARCHAR2 (15);
        lv_transaction    VARCHAR2 (20);
    BEGIN
        lv_invoice_id    := p_invoice_id;
        lv_transaction   := P_transaction_source;

        IF lv_transaction IN
               ('AP INVOICE', 'INTERPROJECT_AP_INVOICES', 'AP VARIANCE',
                'AP NRTAX', 'AP DISCOUNTS', 'AP EXPENSE',
                'AP ERV', 'CSE_IPV_ADJUSTMENT', 'CSE_IPV_ADJUSTMENT_DEPR')
        THEN
            SELECT invoice_date
              INTO lv_invoice_date
              FROM ap_invoices_all aia
             WHERE aia.invoice_id = lv_invoice_id;
        END IF;

        RETURN lv_invoice_date;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_invoice_date;

    ------------------------------------------------------------------------------------------------------------------------------------
    FUNCTION get_vendor_name (p_vendor_id NUMBER)
        RETURN VARCHAR2
    IS
        --Local Variables
        lv_vendor_name   VARCHAR2 (100);
        lv_vendor_id     NUMBER;
    BEGIN
        lv_vendor_id   := p_vendor_id;

        SELECT aps.vendor_name
          INTO lv_vendor_name
          FROM ap_suppliers aps
         WHERE aps.vendor_id = lv_vendor_id;

        RETURN lv_vendor_name;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_vendor_name;

    ------------------------------------------------------------------------------------------------------------------------------------

    FUNCTION get_vendor_number (p_vendor_id NUMBER)
        RETURN VARCHAR2
    IS
        lv_vendor_number   VARCHAR2 (30);
        lv_vendor_id       NUMBER;
    BEGIN
        lv_vendor_id   := p_vendor_id;

        SELECT aps.segment1
          INTO lv_vendor_number
          FROM ap_suppliers aps
         WHERE aps.vendor_id = lv_vendor_id;

        RETURN lv_vendor_number;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_vendor_number;

    ------------------------------------------------------------------------------------------------------------------------------------

    FUNCTION get_po_number (p_exp_item_id NUMBER, p_trx_source VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_po_number     VARCHAR2 (30);
        ln_exp_item_id   NUMBER;
        lv_trx_source    VARCHAR2 (50);
    BEGIN
        lv_po_number     := NULL;
        ln_exp_item_id   := p_exp_item_id;
        lv_trx_source    := p_trx_source;

        IF lv_trx_source IN ('AP VARIANCE', 'AP INVOICE', 'AP NRTAX',
                             'AP DISCOUNTS', 'AP ERV', 'INTERCOMPANY_AP_INVOICES',
                             'INTERPROJECT_AP_INVOICES', 'AP EXPENSE')
        THEN
            SELECT po.segment1 po_number
              INTO lv_po_number
              FROM po_headers_all po, po_distributions_all podist, ap_invoice_distributions_all apdist,
                   pa_expenditure_items_all peia
             WHERE     po.po_header_id = podist.po_header_id
                   AND podist.po_distribution_id = apdist.po_distribution_id
                   AND apdist.invoice_distribution_id =
                       peia.document_distribution_id
                   AND expenditure_item_id = ln_exp_item_id;
        END IF;


        RETURN lv_po_number;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_po_number;
------------------------------------------------------------------------------------------------------------------------------------

END xxd_cip_inv_sup_details_pkg;
/


GRANT EXECUTE ON APPS.XXD_CIP_INV_SUP_DETAILS_PKG TO XXDO
/
