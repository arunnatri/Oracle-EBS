--
-- XXDO_PO_ASN_EXTRACT_PKG  (Package) 
--
--  Dependencies: 
--   FND_GLOBAL (Package)
--   FND_PROFILE (Package)
--   XXDO_PO_ASN_HEADERS_STG (Synonym)
--   XXDO_PO_ASN_POS_STG (Synonym)
--   XXDO_PO_ASN_PO_LINES_STG (Synonym)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:17:15 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_PO_ASN_EXTRACT_PKG"
AS
    /*
    **********************************************************************************************
    $Header:  xxdo_po_asn_extract_pkg.sql   1.0    2014/08/06    10:00:00   Infosys $
    **********************************************************************************************
    */
    -- ***************************************************************************
    --                (c) Copyright Deckers Outdoor Corp.
    --                    All rights reserved
    -- ***************************************************************************
    --
    -- Package Name :  xxdo_po_asn_extract_pkg
    --
    -- Description  :  This is package  for EBS to WMS ASN Interface
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- Date          Author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 06-Aug-14    Infosys            1.0       Created
    -- ***************************************************************************
    g_num_api_version       NUMBER := 1.0;
    g_num_user_id           NUMBER := fnd_global.user_id;
    g_num_login_id          NUMBER := fnd_global.login_id;
    g_num_request_id        NUMBER := fnd_global.conc_request_id;
    g_num_program_id        NUMBER := fnd_global.conc_program_id;
    g_num_program_appl_id   NUMBER := fnd_global.prog_appl_id;
    g_num_org_id            NUMBER := fnd_profile.VALUE ('ORG_ID');

    TYPE g_inv_org_attr_rec_type IS RECORD
    (
        manual_pre_adv_grouping    VARCHAR2 (150),
        partial_asn                VARCHAR2 (150),
        lpn_receiving              VARCHAR2 (150),
        organization_id            NUMBER,
        warehouse_code             VARCHAR2 (30)
    );

    TYPE g_inv_org_attr_tab_type IS TABLE OF g_inv_org_attr_rec_type
        INDEX BY BINARY_INTEGER;

    TYPE g_asn_headers_tab_type IS TABLE OF xxdo_po_asn_headers_stg%ROWTYPE
        INDEX BY BINARY_INTEGER;

    TYPE g_asn_pos_tab_type IS TABLE OF xxdo_po_asn_pos_stg%ROWTYPE
        INDEX BY BINARY_INTEGER;

    TYPE g_asn_po_lines_tab_type IS TABLE OF xxdo_po_asn_po_lines_stg%ROWTYPE
        INDEX BY BINARY_INTEGER;

    PROCEDURE PURGE (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_num_purge_days IN NUMBER);

    PROCEDURE lock_records (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_chr_shipment_no IN VARCHAR2);


    PROCEDURE update_error_records (
        p_out_chr_errbuf            OUT VARCHAR2,
        p_out_chr_retcode           OUT VARCHAR2,
        p_in_chr_shipment_no     IN     VARCHAR2,
        p_in_chr_error_message   IN     VARCHAR2,
        p_in_chr_from_status     IN     VARCHAR2,
        p_in_chr_to_status       IN     VARCHAR2,
        p_in_chr_warehouse       IN     VARCHAR2 DEFAULT NULL);


    FUNCTION get_shipment_container (p_in_num_organization_id   IN NUMBER,
                                     p_in_num_grouping_id       IN NUMBER)
        RETURN VARCHAR2;

    PROCEDURE main (p_out_chr_errbuf          OUT VARCHAR2,
                    p_out_chr_retcode         OUT VARCHAR2,
                    p_in_chr_warehouse     IN     VARCHAR2,
                    p_in_chr_shipment_no   IN     VARCHAR2,
                    p_in_chr_source        IN     VARCHAR2,
                    p_in_chr_dest          IN     VARCHAR2,
                    p_in_num_purge_days    IN     NUMBER,
                    p_in_num_bulk_limit    IN     NUMBER);
--  FUNCTION get_interface_setup RETURN g_interface_setup_rec_type;
END xxdo_po_asn_extract_pkg;
/
