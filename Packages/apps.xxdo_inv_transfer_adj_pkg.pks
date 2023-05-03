--
-- XXDO_INV_TRANSFER_ADJ_PKG  (Package) 
--
--  Dependencies: 
--   FND_GLOBAL (Package)
--   FND_PROFILE (Package)
--   INV_TRANS_ADJ_SER_OBJ_TAB_TYPE (Type)
--   XXDO_INV_TRANS_ADJ_DTL_STG (Synonym)
--   XXDO_INV_TRANS_ADJ_SER_STG (Synonym)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:16:31 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_INV_TRANSFER_ADJ_PKG"
AS
    /*
    **********************************************************************************************
    $Header:  xxdo_inv_transfer_adj_pkg_s.sql   1.0    2014/09/03    10:00:00   Infosys $
    **********************************************************************************************
    */
    -- ***************************************************************************
    --                (c) Copyright Deckers Outdoor Corp.
    --                    All rights reserved
    -- ***************************************************************************
    --
    -- Package Name :  xxdo_inv_transfer_adj_pkg
    --
    -- Description  :  This is package for WMS to EBS inventory transactions interface
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- Date          Author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 03-Sep-14    Infosys            1.0       Created
    --21-Jul-15      Infosys            1.1     Modified new parameter p_process_status identified by P_PROCESS_STATUS
    --03-Sep-15    Infosys            1.2      Modified new parameter p_message_id identified by P_MESSAGE_ID
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
        organization_id    NUMBER,
        warehouse_code     VARCHAR2 (30)
    );


    TYPE g_inv_org_attr_tab_type IS TABLE OF g_inv_org_attr_rec_type
        INDEX BY VARCHAR2 (30);

    TYPE g_ids_int_tab_type IS TABLE OF NUMBER
        INDEX BY BINARY_INTEGER;

    TYPE g_ids_var_tab_type IS TABLE OF NUMBER
        INDEX BY VARCHAR2 (30);

    TYPE g_inv_trans_adj_dtl_tab_type
        IS TABLE OF xxdo_inv_trans_adj_dtl_stg%ROWTYPE
        INDEX BY BINARY_INTEGER;

    TYPE g_inv_trans_adj_ser_tab_type
        IS TABLE OF xxdo_inv_trans_adj_ser_stg%ROWTYPE
        INDEX BY BINARY_INTEGER;


    PROCEDURE purge (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_num_purge_days IN NUMBER);



    PROCEDURE lock_records (
        p_out_chr_errbuf            OUT VARCHAR2,
        p_out_chr_retcode           OUT VARCHAR2,
        p_in_num_trans_seq_id    IN     NUMBER,
        p_out_num_record_count      OUT NUMBER,
        p_process_status         IN     VARCHAR2 DEFAULT 'NEW'); --P_PROCESS_STATUS

    PROCEDURE main (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_chr_process_mode IN VARCHAR2, p_in_chr_warehouse IN VARCHAR2, p_in_chr_from_subinv IN VARCHAR2, p_in_chr_from_locator IN VARCHAR2, p_in_chr_to_subinv IN VARCHAR2, p_in_chr_to_locator IN VARCHAR2, p_in_chr_item IN VARCHAR2, p_in_num_qty IN NUMBER, p_in_chr_uom IN VARCHAR2, p_in_dte_trans_date IN DATE, p_in_chr_reason_code IN VARCHAR2, p_in_chr_comments IN VARCHAR2, p_in_chr_employee_id IN VARCHAR2, p_in_chr_employee_name IN VARCHAR2, p_in_num_trans_seq_id IN NUMBER, --                                p_in_serials_tab   IN g_inv_trans_adj_ser_tab_type,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              p_in_serials_tab IN inv_trans_adj_ser_obj_tab_type
                    , p_in_num_purge_days IN NUMBER, p_process_status IN VARCHAR2 DEFAULT 'NEW', ---  P_PROCESS_STATUS
                                                                                                 p_in_message_id IN VARCHAR2 DEFAULT -1 --P_MESSAGE_ID
                                                                                                                                       );

    PROCEDURE get_current_onhand (p_in_num_org_id          IN     NUMBER,
                                  p_in_chr_sub_inv_code    IN     VARCHAR2,
                                  p_in_num_locator_id      IN     NUMBER,
                                  p_in_num_inv_item_id     IN     NUMBER,
                                  p_out_num_atr_quantity      OUT NUMBER);

    PROCEDURE update_stg_records (p_in_chr_process_mode IN VARCHAR2, p_in_trans_rec IN OUT xxdo_inv_trans_adj_dtl_stg%ROWTYPE, --                                               p_in_serials_tab   IN g_inv_trans_adj_ser_tab_type
                                                                                                                               p_in_serials_tab IN inv_trans_adj_ser_obj_tab_type);

    FUNCTION get_server_timezone (p_in_num_inv_org_local_time   DATE,
                                  p_in_num_inv_org_id           NUMBER)
        RETURN DATE;

    PROCEDURE process_batch (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_num_purge_days IN NUMBER
                             , p_process_status IN VARCHAR2 DEFAULT 'NEW'); --P_PROCESS_STATUS
END xxdo_inv_transfer_adj_pkg;
/


GRANT EXECUTE ON APPS.XXDO_INV_TRANSFER_ADJ_PKG TO SOA_INT
/
