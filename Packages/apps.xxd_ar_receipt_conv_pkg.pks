--
-- XXD_AR_RECEIPT_CONV_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:19:11 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS.xxd_ar_receipt_conv_pkg
AS
    PROCEDURE main (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_org_name IN VARCHAR2
                    , pi_type IN VARCHAR2, p_debug IN VARCHAR2);

    PROCEDURE receipt_extract (x_retcode OUT NUMBER, x_errbuff OUT VARCHAR2, p_debug IN VARCHAR2
                               , p_org_name IN VARCHAR2);

    PROCEDURE receipt_validate (x_retcode OUT NUMBER, x_errbuff OUT VARCHAR2, p_debug IN VARCHAR2
                                , p_org_name IN VARCHAR2);

    PROCEDURE receipt_load (x_retcode OUT NUMBER, x_errbuff OUT VARCHAR2, p_org_name IN VARCHAR2
                            , p_debug IN VARCHAR2);

    PROCEDURE print_log_prc (p_debug_flag IN VARCHAR2, p_message IN VARCHAR2);

    PROCEDURE get_new_org_id (p_old_org_name IN VARCHAR2, p_debug_flag IN VARCHAR2, x_new_org_id OUT NUMBER
                              , x_new_org_name OUT VARCHAR2);

    PROCEDURE receipt_on_account_apply (x_retcode OUT NUMBER, x_errbuff OUT VARCHAR2, p_org_id IN NUMBER
                                        , p_debug IN VARCHAR2);
END;
/
