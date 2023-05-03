--
-- XXDO_ONT_WMS_INTF_UTIL_PKG  (Package) 
--
--  Dependencies: 
--   FND_GLOBAL (Package)
--   FND_PROFILE (Package)
--   OE_HOLD_SOURCES_ALL (Synonym)
--   OE_ORDER_HEADERS (Synonym)
--   OE_ORDER_LINES (Synonym)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:16:59 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_ONT_WMS_INTF_UTIL_PKG"
AS
    /*
    **********************************************************************************************
    $Header:  xxdo_ont_wms_intf_util_pkg.sql   1.0    2014/07/15    10:00:00   Infosys $
    **********************************************************************************************
    */
    -- ***************************************************************************
    --                (c) Copyright Deckers Outdoor Corp.
    --                    All rights reserved
    -- ***************************************************************************
    --
    -- Package Name :  xxdo_ont_wms_intf_util_pkg
    --
    -- Description  :  This package has the utilities required the Interfaces between EBS and WMS
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- Date          Author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 15-Jul-14    Infosys            1.0       Created
    -- ***************************************************************************


    g_num_api_version                  NUMBER := 1.0;
    g_num_user_id                      NUMBER := fnd_global.user_id;
    g_num_login_id                     NUMBER := fnd_global.login_id;
    g_num_request_id                   NUMBER := fnd_global.conc_request_id;
    g_num_program_id                   NUMBER := fnd_global.conc_program_id;
    g_num_program_appl_id              NUMBER := fnd_global.prog_appl_id;
    g_num_org_id                       NUMBER := fnd_profile.VALUE ('ORG_ID');

    g_chr_ar_release_reason   CONSTANT VARCHAR2 (10) := 'CRED-REL';
    g_chr_om_release_reason   CONSTANT VARCHAR2 (10) := 'CS-REL';

    TYPE g_interface_setup_rec_type IS RECORD
    (
        Interface_code        VARCHAR2 (250),
        Program_code          VARCHAR2 (250),
        Description           VARCHAR2 (250),
        Interface_type        VARCHAR2 (250),
        XML_Message_type      VARCHAR2 (250),
        source_server         VARCHAR2 (250),
        source_path           VARCHAR2 (250),
        destination_server    VARCHAR2 (250),
        destination_path      VARCHAR2 (250),
        archive_path          VARCHAR2 (250),
        filename              VARCHAR2 (250),
        file_sequence         VARCHAR2 (250),
        from_email_id         VARCHAR2 (250),
        to_email_ids          VARCHAR2 (250),
        last_run_time         DATE
    );


    TYPE g_hold_source_rec_type IS RECORD
    (
        hold_id             oe_hold_sources_all.hold_id%TYPE,
        hold_entity_code    oe_hold_sources_all.hold_entity_code%TYPE,
        hold_entity_id      oe_hold_sources_all.hold_entity_id%TYPE,
        header_id           oe_order_headers.header_id%TYPE,
        line_id             oe_order_lines.line_id%TYPE,
        hold_type           VARCHAR2 (60),
        hold_name           VARCHAR2 (240)
    );

    TYPE g_hold_source_tbl_type IS TABLE OF g_hold_source_rec_type
        INDEX BY BINARY_INTEGER;

    FUNCTION get_sku (p_in_num_inventory_item_id IN NUMBER)
        RETURN VARCHAR2;


    PROCEDURE reapply_holds (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_hold_source_tbl IN g_hold_source_tbl_type);

    PROCEDURE release_holds (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_io_hold_source_tbl IN OUT g_hold_source_tbl_type
                             , p_in_num_header_id IN NUMBER);

    FUNCTION get_last_run_time (p_in_chr_interface_prgm_name IN VARCHAR2)
        RETURN DATE;

    PROCEDURE set_last_run_time (p_in_chr_interface_prgm_name   IN VARCHAR2,
                                 p_in_dte_run_time              IN DATE);

    FUNCTION HIGHJUMP_ENABLED_WHSE (p_org_code IN VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION HIGHJUMP_ENABLED_Delivery (p_delivery_id IN NUMBER)
        RETURN VARCHAR2;
END xxdo_ont_wms_intf_util_pkg;
/
