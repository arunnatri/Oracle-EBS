--
-- XXDO_PO_ASN_RECEIPT_PKG  (Package) 
--
--  Dependencies: 
--   FND_GLOBAL (Package)
--   FND_PROFILE (Package)
--   XXDO_PO_ASN_RECEIPT_DTL_STG (Synonym)
--   XXDO_PO_ASN_RECEIPT_HEAD_STG (Synonym)
--   XXDO_PO_ASN_RECEIPT_SER_STG (Synonym)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:17:17 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_PO_ASN_RECEIPT_PKG"
AS
    /*
    **********************************************************************************************
    $Header:  xxdo_po_asn_receipt_pkg_s.sql   1.0    2014/08/18    10:00:00   Infosys $
    **********************************************************************************************
    */
    -- ***************************************************************************
    --                (c) Copyright Deckers Outdoor Corp.
    --                    All rights reserved
    -- ***************************************************************************
    --
    -- Package Name :  xxdo_po_asn_receipt_pkg
    --
    -- Description  :  This is package  for WMS to EBS ASN Receipt Interface
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- Date          Author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 18-Aug-14    Infosys            1.0       Created
    -- ***************************************************************************
    g_num_api_version            NUMBER := 1.0;
    g_num_user_id                NUMBER := fnd_global.user_id;
    g_num_login_id               NUMBER := fnd_global.login_id;
    g_num_request_id             NUMBER := fnd_global.conc_request_id;
    g_num_program_id             NUMBER := fnd_global.conc_program_id;
    g_num_program_appl_id        NUMBER := fnd_global.prog_appl_id;
    g_num_org_id                 NUMBER := fnd_profile.VALUE ('ORG_ID');
    g_chr_asn_receipt_msg_type   VARCHAR2 (30) := '730';

    TYPE g_inv_org_attr_rec_type IS RECORD
    (
        lpn_receiving      VARCHAR2 (150),
        partial_asn        VARCHAR2 (150),
        organization_id    NUMBER,
        warehouse_code     VARCHAR2 (30)
    );

    TYPE g_inv_org_attr_tab_type IS TABLE OF g_inv_org_attr_rec_type
        INDEX BY VARCHAR2 (30);

    TYPE g_ids_int_tab_type IS TABLE OF NUMBER
        INDEX BY BINARY_INTEGER;

    TYPE g_ids_var_tab_type IS TABLE OF NUMBER
        INDEX BY VARCHAR2 (30);

    TYPE g_asn_receipt_headers_tab_type
        IS TABLE OF xxdo_po_asn_receipt_head_stg%ROWTYPE;

    TYPE g_asn_receipt_dtls_tab_type
        IS TABLE OF xxdo_po_asn_receipt_dtl_stg%ROWTYPE;

    TYPE g_carton_sers_tab_type
        IS TABLE OF xxdo_po_asn_receipt_ser_stg%ROWTYPE;

    PROCEDURE PURGE (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_num_purge_days IN NUMBER);

    FUNCTION get_inventory_item_id (p_in_chr_item_number     IN VARCHAR2,
                                    p_in_num_master_org_id   IN NUMBER)
        RETURN NUMBER;

    PROCEDURE lock_records (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_chr_warehouse IN VARCHAR2
                            , p_in_chr_appointment_id IN VARCHAR2, p_in_chr_rcpt_type IN VARCHAR2, p_out_num_record_count OUT NUMBER);

    PROCEDURE update_error_records (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_chr_appointment_id IN VARCHAR2, p_in_num_receipt_head_id IN NUMBER, p_in_chr_shipment_no IN VARCHAR2, p_in_num_rcpt_dtl_seq_id IN NUMBER, p_in_chr_error_message IN VARCHAR2, p_in_chr_from_status IN VARCHAR2, p_in_chr_to_status IN VARCHAR2
                                    , p_in_chr_warehouse IN VARCHAR2);

    /*
       PROCEDURE reset_error_records (p_out_chr_errbuf   OUT VARCHAR2,
                                                         p_out_chr_retcode OUT VARCHAR2,
                                                         p_in_chr_shipment_no  IN VARCHAR2);

    */
    PROCEDURE main (p_out_chr_errbuf             OUT VARCHAR2,
                    p_out_chr_retcode            OUT VARCHAR2,
                    p_in_chr_warehouse        IN     VARCHAR2,
                    p_in_chr_appointment_id   IN     VARCHAR2,
                    p_in_chr_source           IN     VARCHAR2,
                    p_in_chr_dest             IN     VARCHAR2,
                    p_in_num_purge_days       IN     NUMBER,
                    p_in_num_bulk_limit       IN     NUMBER);

    PROCEDURE insert_asn_data (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_num_bulk_limit IN NUMBER
                               , p_out_num_group_id OUT NUMBER);

    PROCEDURE upload_xml (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_chr_inbound_directory IN VARCHAR2
                          , p_in_chr_file_name IN VARCHAR2);

    PROCEDURE extract_xml_data (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_num_bulk_limit IN NUMBER);


    PROCEDURE insert_po_data (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_num_bulk_limit IN NUMBER
                              , p_out_num_group_id OUT NUMBER);


    PROCEDURE update_po_error_records (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_chr_appointment_id IN VARCHAR2, p_in_num_receipt_head_id IN NUMBER, p_in_chr_po_no IN VARCHAR2, p_in_num_rcpt_dtl_seq_id IN NUMBER, p_in_chr_error_message IN VARCHAR2, p_in_chr_from_status IN VARCHAR2, p_in_chr_to_status IN VARCHAR2
                                       , p_in_chr_warehouse IN VARCHAR2);

    PROCEDURE lock_po_records (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_chr_warehouse IN VARCHAR2
                               , p_in_chr_appointment_id IN VARCHAR2, p_in_chr_rcpt_type IN VARCHAR2, p_out_num_record_count OUT NUMBER);

    PROCEDURE process_corrections (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_chr_warehouse IN VARCHAR2);
END xxdo_po_asn_receipt_pkg;
/
