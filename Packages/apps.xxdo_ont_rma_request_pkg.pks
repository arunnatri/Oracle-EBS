--
-- XXDO_ONT_RMA_REQUEST_PKG  (Package) 
--
--  Dependencies: 
--   FND_API (Package)
--   FND_GLOBAL (Package)
--   XXDO_ONT_RMA_HDR_STG (Synonym)
--   XXDO_ONT_RMA_LINE_SERL_STG (Synonym)
--   XXDO_ONT_RMA_LINE_STG (Synonym)
--   UTL_SMTP (Synonym)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:16:53 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_ONT_RMA_REQUEST_PKG"
AS
    /*
    **********************************************************************************************
    $Header:  xxdo_ont_rma_request_pkg.sql   1.0    2014/08/18   10:00:00   Infosys $
    **********************************************************************************************
    */
    -- ***************************************************************************
    --                (c) Copyright Deckers Outdoor Corp.
    --                    All rights reserved
    -- ***************************************************************************
    --
    -- Package Name :  xxdo_ont_rma_request_pkg
    --
    -- Description  :  This is package  for WMS to EBS UnExpected Return Receiving
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- Date          Author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 18-Aug-2014    Infosys            1.0       Created
    -- ***************************************************************************
    TYPE g_rma_request_headers_tab_type
        IS TABLE OF xxdo_ont_rma_hdr_stg%ROWTYPE;

    TYPE g_rma_request_dtls_tab_type
        IS TABLE OF xxdo_ont_rma_line_stg%ROWTYPE;

    TYPE g_rma_sers_tab_type IS TABLE OF xxdo_ont_rma_line_serl_stg%ROWTYPE;

    -------------------------
    g_num_debug                   NUMBER := 0;
    g_dte_sysdate                 DATE := SYSDATE;
    g_num_api_version             NUMBER := 1.0;
    g_chr_status                  VARCHAR2 (100) := 'UNPROCESSED';
    g_num_user_id                 NUMBER := fnd_global.user_id;
    g_num_resp_id                 NUMBER := fnd_global.resp_id;
    g_num_resp_appl_id            NUMBER := fnd_global.resp_appl_id;
    g_num_login_id                NUMBER := fnd_global.login_id;
    g_num_request_id              NUMBER := fnd_global.conc_request_id;
    g_num_prog_appl_id            NUMBER := fnd_global.prog_appl_id;
    g_dt_current_date             DATE := SYSDATE;
    g_chr_status_code             VARCHAR2 (1) := '0';
    g_chr_status_msg              VARCHAR2 (4000);
    g_ret_sts_warning             VARCHAR2 (1) := 'W';
    g_ret_success        CONSTANT VARCHAR2 (1) := fnd_api.g_ret_sts_success;
    g_ret_error          CONSTANT VARCHAR2 (1) := fnd_api.g_ret_sts_error;
    g_ret_unexp_error    CONSTANT VARCHAR2 (1)
                                      := fnd_api.g_ret_sts_unexp_error ;
    g_chr_rma_receipt_msg_type    VARCHAR2 (30) := '730';

    g_chr_rma_request_prgm_name   VARCHAR2 (30) := 'XXDO_RAREQ';
    g_smtp_connection             UTL_SMTP.connection := NULL;
    g_num_connection_flag         NUMBER := 0;


    PROCEDURE upload_xml (p_errbuf OUT VARCHAR2, p_retcode OUT NUMBER, p_in_chr_inbound_directory VARCHAR2
                          , p_in_chr_file_name VARCHAR2);

    PROCEDURE extract_xml_data (p_errbuf                 OUT VARCHAR2,
                                p_retcode                OUT NUMBER,
                                p_in_num_bulk_limit   IN     NUMBER);

    PROCEDURE validate_all_records (p_retcode     OUT NUMBER,
                                    p_error_buf   OUT VARCHAR2);

    PROCEDURE mail_hold_report (p_out_chr_errbuf    OUT VARCHAR2,
                                p_out_chr_retcode   OUT VARCHAR2);

    PROCEDURE send_mail_header (p_in_chr_msg_from IN VARCHAR2, p_in_chr_msg_to IN VARCHAR2, p_in_chr_msg_subject IN VARCHAR2
                                , p_out_num_status OUT NUMBER);

    PROCEDURE send_mail_line (p_in_chr_msg_text   IN     VARCHAR2,
                              p_out_num_status       OUT NUMBER);

    PROCEDURE send_mail_close (p_out_num_status OUT NUMBER);


    PROCEDURE main_validate (errbuf OUT VARCHAR2, retcode OUT NUMBER, p_wh_code IN VARCHAR2, p_rma_ref IN VARCHAR2, p_source IN VARCHAR2 DEFAULT 'WMS', p_destination IN VARCHAR2 DEFAULT 'EBS'
                             , p_purge_days IN NUMBER DEFAULT 30, p_debug IN VARCHAR2 DEFAULT 'Y', p_leap_days IN NUMBER DEFAULT 30);
END xxdo_ont_rma_request_pkg;
/
