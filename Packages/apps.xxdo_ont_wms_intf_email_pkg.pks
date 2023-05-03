--
-- XXDO_ONT_WMS_INTF_EMAIL_PKG  (Package) 
--
--  Dependencies: 
--   FND_GLOBAL (Package)
--   UTL_SMTP (Synonym)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:16:58 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_ONT_WMS_INTF_EMAIL_PKG"
AS
    /*
    **********************************************************************************************
    $Header:  xxdo_ont_wms_intf_email_pkg_s.sql   1.0    2014/07/15    10:00:00   Infosys $
    **********************************************************************************************
    */
    -- ***************************************************************************
    --                (c) Copyright Deckers Outdoor Corp.
    --                    All rights reserved
    -- ***************************************************************************
    --
    -- Package Name :  xxdo_ont_wms_intf_email_pkg
    --
    -- Description  :  This package has the utilities required the Interfaces between EBS and WMS
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- Date          Author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 15-Jul-14    Infosys            1.0       Created
    -- ***************************************************************************


    g_num_user_id                  NUMBER := fnd_global.user_id;
    g_num_login_id                 NUMBER := fnd_global.login_id;
    g_num_request_id               NUMBER := fnd_global.conc_request_id;
    g_num_program_id               NUMBER := fnd_global.conc_program_id;
    g_num_program_appl_id          NUMBER := fnd_global.prog_appl_id;
    g_smtp_connection              UTL_SMTP.connection := NULL;
    g_num_connection_flag          NUMBER := 0;

    g_dte_sysdate                  DATE;
    g_chr_instance                 VARCHAR2 (100);
    g_num_bulk_limit               NUMBER := 1000;
    g_num_no_of_days               NUMBER := NULL;

    g_chr_inv_adj_prgm_name        VARCHAR2 (30) := 'XXDO_INV_ADJ';
    g_chr_asn_receipt_prgm_name    VARCHAR2 (30) := 'XXDO_ASNRCPT';
    g_chr_ship_confirm_prgm_name   VARCHAR2 (30) := 'XXDO_SHIP';
    g_chr_rma_receipt_prgm_name    VARCHAR2 (30) := 'XXDO_RAREC';
    g_chr_rma_request_prgm_name    VARCHAR2 (30) := 'XXDO_RAREQ';
    g_chr_order_status_prgm_name   VARCHAR2 (30) := 'XXDO_ORDER_STATUS';
    g_chr_addr_corr_report_name    VARCHAR2 (30) := 'XXDO_ADDR_CORR_REPORT';


    PROCEDURE mail_inv_adj_err_report (p_out_chr_errbuf    OUT VARCHAR2,
                                       p_out_chr_retcode   OUT VARCHAR2);

    PROCEDURE mail_asn_receipt_err_report (p_out_chr_errbuf    OUT VARCHAR2,
                                           p_out_chr_retcode   OUT VARCHAR2);

    PROCEDURE mail_ship_confirm_err_report (p_out_chr_errbuf    OUT VARCHAR2,
                                            p_out_chr_retcode   OUT VARCHAR2);

    PROCEDURE mail_order_status_err_report (p_out_chr_errbuf    OUT VARCHAR2,
                                            p_out_chr_retcode   OUT VARCHAR2);

    PROCEDURE mail_rma_receipt_err_report (p_out_chr_errbuf    OUT VARCHAR2,
                                           p_out_chr_retcode   OUT VARCHAR2);


    PROCEDURE mail_rma_request_err_report (p_out_chr_errbuf    OUT VARCHAR2,
                                           p_out_chr_retcode   OUT VARCHAR2);

    /*
        PROCEDURE mail_address_corr_report(p_out_chr_errbuf     OUT VARCHAR2,
                                                                 p_out_chr_retcode     OUT VARCHAR2);




        PROCEDURE send_email(p_out_chr_errbuf     OUT VARCHAR2,
                                            p_out_chr_retcode     OUT VARCHAR2);

    */

    PROCEDURE send_mail_header (p_in_chr_msg_from IN VARCHAR2, p_in_chr_msg_to IN VARCHAR2, p_in_chr_msg_subject IN VARCHAR2
                                , p_out_num_status OUT NUMBER);

    PROCEDURE send_mail_line (p_in_chr_msg_text   IN     VARCHAR2,
                              p_out_num_status       OUT NUMBER);

    PROCEDURE send_mail_close (p_out_num_status OUT NUMBER);

    PROCEDURE main (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_chr_interface IN VARCHAR2
                    , p_in_num_no_of_days IN NUMBER);
END xxdo_ont_wms_intf_email_pkg;
/
