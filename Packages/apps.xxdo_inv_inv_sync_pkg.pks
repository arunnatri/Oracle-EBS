--
-- XXDO_INV_INV_SYNC_PKG  (Package) 
--
--  Dependencies: 
--   FND_GLOBAL (Package)
--   FND_PROFILE (Package)
--   XXDO_INV_SYNC_SERIAL_STG (Synonym)
--   XXDO_INV_SYNC_STG (Synonym)
--   UTL_SMTP (Synonym)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:16:23 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_INV_INV_SYNC_PKG"
AS
    /*
    *****************************************************************************
    $Header:  xxdo_inv_inv_sync_pkg.sql   1.0    2014/09/03    10:00:00   Infosys $
    *****************************************************************************
    */
    -- ***************************************************************************
    --                (c) Copyright Deckers Outdoor Corp.
    --                    All rights reserved
    -- ***************************************************************************
    --
    -- Package Name :  xxdo_inv_inv_sync_pkg
    --
    -- Description  :  This is package for WMS to EBS Inventory Synchronization interface
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- Date          Author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 03-Sep-14    Infosys            1.0       Created
    -- ***************************************************************************
    g_num_user_id             NUMBER := fnd_global.user_id;
    g_num_login_id            NUMBER := fnd_global.login_id;
    g_num_request_id          NUMBER := fnd_global.conc_request_id;
    g_num_program_id          NUMBER := fnd_global.conc_program_id;
    g_num_program_appl_id     NUMBER := fnd_global.prog_appl_id;
    g_num_org_id              NUMBER := fnd_profile.VALUE ('ORG_ID');
    g_chr_inv_sync_msg_type   VARCHAR2 (30) := '720';
    g_smtp_connection         UTL_SMTP.connection := NULL;
    g_num_connection_flag     NUMBER := 0;

    g_dte_sysdate             DATE;
    g_chr_instance            VARCHAR2 (100);
    g_num_bulk_limit          NUMBER := 1000;
    g_num_no_of_days          NUMBER := NULL;

    TYPE g_inv_org_attr_rec_type IS RECORD
    (
        organization_id    NUMBER,
        warehouse_code     VARCHAR2 (30)
    );


    TYPE g_inv_org_attr_tab_type IS TABLE OF g_inv_org_attr_rec_type
        INDEX BY VARCHAR2 (30);

    TYPE g_ids_var_tab_type IS TABLE OF NUMBER
        INDEX BY VARCHAR2 (30);

    TYPE g_inv_sync_stg_tab_type IS TABLE OF xxdo_inv_sync_stg%ROWTYPE
        INDEX BY BINARY_INTEGER;

    TYPE g_inv_sync_rec_tab_type IS TABLE OF NUMBER
        INDEX BY BINARY_INTEGER;

    TYPE g_inv_sync_serial__tab_type
        IS TABLE OF xxdo_inv_sync_serial_stg%ROWTYPE
        INDEX BY BINARY_INTEGER;



    /*PROCEDURE send_mail_with_attachment (p_in_from                     IN     VARCHAR2,
                                                                 p_in_subject                  IN     VARCHAR2,
                                                                 p_in_attachment            IN     CLOB,
                                                                 p_in_file_name              IN     VARCHAR2,
                                                                 p_out_chr_ret_message OUT  VARCHAR2,
                                                                 p_out_chr_ret_code       OUT   VARCHAR2
                                                                );*/


    PROCEDURE main (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_num_snapshot_id IN NUMBER
                    , p_in_num_purge_days IN NUMBER DEFAULT 30);
END xxdo_inv_inv_sync_pkg;
/
