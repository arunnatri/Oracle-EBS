--
-- XXD_AR_TRX_OUTBOUND_PKG  (Package) 
--
--  Dependencies: 
--   FND_API (Package)
--   FND_GLOBAL (Package)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:19:15 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_AR_TRX_OUTBOUND_PKG"
/***************************************************************************************
* Program Name : XXDO_AR_TRX_OUTBOUND_PKG                                              *
* Language     : PL/SQL                                                                *
* Description  : Package to generate outbound files for Pagero integration             *
*                                                                                      *
* History      :                                                                       *
*                                                                                      *
* WHO          :       WHAT      Desc                                    WHEN          *
* -------------- ----------------------------------------------------------------------*
* Kishan Reddy         1.0       Initial Version                         10-MAY-2022   *
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

    g_index                       NUMBER := 0;

    TYPE error_rec_type IS RECORD
    (
        trx_id              NUMBER := NULL,
        trx_number          VARCHAR2 (20) := NULL,
        trx_date            DATE := NULL,
        ERROR_CODE          VARCHAR2 (30) := NULL,
        error_message       VARCHAR2 (500) := NULL,
        creation_date       DATE := SYSDATE,
        created_by          NUMBER := fnd_global.user_id,
        last_update_date    DATE := SYSDATE,
        last_updated_by     NUMBER := fnd_global.user_id,
        request_id          NUMBER := FND_GLOBAL.CONC_REQUEST_ID
    );

    TYPE error_tbl_type IS TABLE OF error_rec_type
        INDEX BY BINARY_INTEGER;

    g_error_tbl                   error_tbl_type;

    FUNCTION remove_junk (p_input IN VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION check_column_enabled (pv_column            VARCHAR2,
                                   pv_company_segment   VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION get_tax_exempt_text (p_org_id IN NUMBER, p_invoice_id IN NUMBER)
        RETURN VARCHAR2;

    FUNCTION get_tax_code (p_org_id IN NUMBER, p_invoice_id IN NUMBER)
        RETURN VARCHAR2;

    FUNCTION get_tot_net_amount (p_customer_trx_id IN NUMBER)
        RETURN NUMBER;

    FUNCTION get_h_discount_amount (p_customer_trx_id IN NUMBER)
        RETURN NUMBER;

    FUNCTION get_comp_segment (pn_trx_id NUMBER, pn_trx_line_id NUMBER)
        RETURN VARCHAR2;

    PROCEDURE main (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, pn_org_id IN NUMBER, pv_reprocess_flag IN VARCHAR2, pv_trans_enabled_tmp IN VARCHAR2, pv_trx_number IN VARCHAR2, pd_trx_date_from IN VARCHAR2, pd_trx_date_to IN VARCHAR2, pn_customer_id IN NUMBER
                    , pn_site_id IN NUMBER, p_file_path IN VARCHAR2);
END XXD_AR_TRX_OUTBOUND_PKG;
/
