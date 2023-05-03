--
-- XXD_AP_IC_INV_OUTBOUND_PKG  (Package) 
--
--  Dependencies: 
--   DO_MAIL_UTILS (Package)
--   FND_API (Package)
--   FND_GLOBAL (Package)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:18:24 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_AP_IC_INV_OUTBOUND_PKG"
/***************************************************************************************
* Program Name : XXD_AP_CB_INV_OUTBOUND_PKG                                            *
* Language     : PL/SQL                                                                *
* Description  : Package                                                               *
*                                                                                      *
* History      :                                                                       *
*                                                                                      *
* WHO          :       WHAT      Desc                                    WHEN          *
* -------------- ----------------------------------------------------------------------*
* Kishan Reddy         1.0       Initial Version                         15-Jun-2022   *
* -------------------------------------------------------------------------------------*/
AS
    --Global Constants
    -- Return Statuses
    gv_ret_success       CONSTANT VARCHAR2 (1) := fnd_api.g_ret_sts_success;
    gv_ret_error         CONSTANT VARCHAR2 (1) := fnd_api.g_ret_sts_error;
    gv_ret_unexp_error   CONSTANT VARCHAR2 (1)
                                      := fnd_api.g_ret_sts_unexp_error ;
    gv_ret_warning       CONSTANT VARCHAR2 (1) := 'W';
    gn_success           CONSTANT NUMBER := 0;
    gn_warning           CONSTANT NUMBER := 1;
    gn_error             CONSTANT NUMBER := 2;
    -- gv_delimiter              VARCHAR2 (10)   := '|';
    g_index                       NUMBER := 0;

    TYPE error_rec_type IS RECORD
    (
        invoice_id          NUMBER := NULL,
        invoice_number      VARCHAR2 (50) := NULL,
        invoice_date        DATE := NULL,
        ERROR_CODE          VARCHAR2 (30) := NULL,
        error_message       VARCHAR2 (500) := NULL,
        creation_date       DATE := SYSDATE,
        created_by          NUMBER := fnd_global.user_id,
        last_update_date    DATE := SYSDATE,
        last_updated_by     NUMBER := fnd_global.user_id,
        request_id          NUMBER := fnd_global.conc_request_id
    );

    TYPE error_tbl_type IS TABLE OF error_rec_type
        INDEX BY BINARY_INTEGER;

    g_error_tbl                   error_tbl_type;

    FUNCTION get_lookup_value (pv_column_name   IN VARCHAR2,
                               pv_company       IN VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION remove_junk (p_input IN VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION get_routing_code (pv_company VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION get_document_type (p_ic_tax_code IN VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION get_h_tot_net_amount (p_company      IN VARCHAR2,
                                   p_invoice_id   IN NUMBER)
        RETURN NUMBER;

    FUNCTION get_h_tot_tax_amount (p_company IN VARCHAR2, p_invoice_id IN NUMBER, p_attribute_id IN NUMBER
                                   , p_ic_category IN VARCHAR2)
        RETURN NUMBER;

    FUNCTION get_vat_rate (p_invoice_id     IN NUMBER,
                           p_attribute_id   IN NUMBER,
                           p_line_number    IN NUMBER)
        RETURN NUMBER;

    FUNCTION get_vat_amount (p_company IN VARCHAR2, p_invoice_id IN NUMBER, p_attribute_id IN NUMBER
                             , p_ic_category IN VARCHAR2)
        RETURN NUMBER;

    FUNCTION get_vat_net_amount (p_company IN VARCHAR2, p_invoice_id IN NUMBER, p_ic_tax_rate IN NUMBER
                                 , p_ic_category IN VARCHAR2)
        RETURN NUMBER;


    FUNCTION get_cm_h_tot_net_amount (p_company      IN VARCHAR2,
                                      p_invoice_id   IN NUMBER)
        RETURN NUMBER;

    FUNCTION get_cm_h_tot_tax_amount (p_company      IN VARCHAR2,
                                      p_invoice_id   IN NUMBER)
        RETURN NUMBER;

    FUNCTION get_cm_vat_amount (p_company IN VARCHAR2, p_invoice_id IN NUMBER, p_ic_tax_rate IN NUMBER
                                , p_tax_code IN VARCHAR2)
        RETURN NUMBER;

    FUNCTION get_cm_vat_net_amount (p_company IN VARCHAR2, p_invoice_id IN NUMBER, p_ic_tax_rate IN NUMBER
                                    , p_tax_code IN VARCHAR2)
        RETURN NUMBER;

    FUNCTION get_email_ids (pv_lookup_type VARCHAR2, pv_inst_name VARCHAR2)
        RETURN do_mail_utils.tbl_recips;

    PROCEDURE main (errbuf OUT NOCOPY VARCHAR2, retcode OUT NOCOPY VARCHAR2, pv_company_segment IN VARCHAR2, pv_reprocess_flag IN VARCHAR2, pv_inv_enabled_tmp IN VARCHAR2, pv_invoice_num IN NUMBER
                    , pv_end_date IN VARCHAR2);
END xxd_ap_ic_inv_outbound_pkg;
/
