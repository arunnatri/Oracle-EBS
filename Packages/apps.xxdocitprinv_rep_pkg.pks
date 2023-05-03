--
-- XXDOCITPRINV_REP_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:12:32 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS.xxdocitprinv_rep_pkg
AS
    PROCEDURE prog_main (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pn_org_id IN NUMBER, p_type_extract IN VARCHAR2, pd_from_date IN VARCHAR2, pd_to_date IN VARCHAR2, p_file_name IN VARCHAR2, p_source IN VARCHAR2, p_iden_rec IN VARCHAR2
                         , p_sent_yn IN VARCHAR2);

    PROCEDURE update_data_stg_t (p_type IN VARCHAR2, p_negative_line_adjustment_id IN NUMBER, p_negative_tax_adjustment_id IN NUMBER, p_negative_freight_adjust_id IN NUMBER, p_negative_charges_adjust_id IN NUMBER, p_request_id IN NUMBER
                                 , p_customer_trx_id IN NUMBER, p_status IN VARCHAR2, p_error_message IN VARCHAR2);

    PROCEDURE update_ctl_stg_t (p_request_id IN NUMBER, p_ftp_status IN VARCHAR2, p_file_name IN VARCHAR2);

    PROCEDURE insert_ctl_stg_t (p_request_id IN NUMBER, p_file_name IN VARCHAR2, p_ftp_status IN VARCHAR2
                                , p_cust_count IN NUMBER, p_invoice_count IN NUMBER, p_tot_inv_amt IN NUMBER);

    FUNCTION adj_amount_sum (pn_customer_trx_id      NUMBER,
                             pn_receivables_trx_id   NUMBER)
        RETURN NUMBER;
END;
/
