--
-- XXD_WMS_HJ_INT_PKG  (Package) 
--
--  Dependencies: 
--   FND_API (Package)
--   XXD_EBS_HJ_PICK_TKT_BATCH_TBL (Type)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:26:03 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_WMS_HJ_INT_PKG"
AS
    /******************************************************************************
       NAME             :   xxd_wms_hj_int_pkg
       PURPOSE          :   Integration between EBS and HJ

       REVISIONS:
       Ver      Date        Author              Description
       -------  ----------  -----------------   ------------------------------------
       2.0      4/4/2018    Kranthi Bollam      2. a. Renamed the package
                                                   b. Modified for CCR0007089
       2.1      21/06/2018  Kranthi Bollam      CCR0007376 - fixed the issue where
                                                cursor should not extract/pull the
                                                Pick tickets status in header staging
                                                table is in INPROCESS or NEW.
                                                Also Added get_sales_channel for fixing
                                                Performance issue
       2.3     02/06/2019  Kranthi Bollam       CCR0007774 - Logic change in Deriving updated Deliveries and also performance improvements
                                                Added procedure debug_prc to capture exceptions in SOA_CALL.
       2.5     10/24/2019  Tejaswi Gangumalla   CCR0008279(10.6) - Restrict Planned for Cross docking status order to HJ
       3.0     08/10/2020 Greg Jensen           CCR0008657 - VAS Automation
    3.1     04/15/2021 Suraj Valluri         US6
    ******************************************************************************/
    --Global Variables declaration
    --Global constants and Return Statuses
    --Added below global variables for change 2.0
    g_miss_num          CONSTANT NUMBER := apps.fnd_api.g_miss_num;
    g_miss_char         CONSTANT VARCHAR2 (1) := apps.fnd_api.g_miss_char;
    g_miss_date         CONSTANT DATE := apps.fnd_api.g_miss_date;
    g_ret_success       CONSTANT VARCHAR2 (1) := apps.fnd_api.g_ret_sts_success;
    g_ret_error         CONSTANT VARCHAR2 (1) := apps.fnd_api.g_ret_sts_error;
    g_ret_unexp_error   CONSTANT VARCHAR2 (1)
                                     := apps.fnd_api.g_ret_sts_unexp_error ;
    g_ret_warning       CONSTANT VARCHAR2 (1) := 'W';
    g_success           CONSTANT NUMBER := 0;
    g_warning           CONSTANT NUMBER := 1;
    g_error             CONSTANT NUMBER := 2;

    PROCEDURE msg (in_chr_message VARCHAR2);

    PROCEDURE extract_pickticket_stage_data (
        p_organization     IN     NUMBER,
        p_pick_num         IN     NUMBER,
        p_so_num           IN     NUMBER,
        p_brand            IN     VARCHAR2              --Added for change 2.0
                                          ,
        p_sales_channel    IN     VARCHAR2              --Added for change 2.0
                                          ,
        p_regenerate_xml   IN     VARCHAR2              --Added for change 2.0
                                          ,
        p_last_run_date    IN     DATE,
        p_source           IN     VARCHAR2,
        p_dest             IN     VARCHAR2,
        p_retcode             OUT NUMBER,
        p_error_buf           OUT VARCHAR2);

    PROCEDURE pick_extract_main (errbuf OUT VARCHAR2, retcode OUT NUMBER, p_organization IN NUMBER, p_pick_number IN NUMBER, p_so_number IN NUMBER, p_brand IN VARCHAR2, p_sales_channel IN VARCHAR2, p_regenerate_xml IN VARCHAR2, p_debug_level IN VARCHAR2
                                 , p_source IN VARCHAR2, p_dest IN VARCHAR2);

    FUNCTION parse_attributes (p_attributes      IN VARCHAR2,
                               p_search_string   IN VARCHAR2)
        RETURN VARCHAR2;

    --Added below Function for change 2.0 to get the program last run time for Warehouse and sales channel
    FUNCTION get_last_run_time (pn_warehouse_id    IN NUMBER,
                                pv_sales_channel   IN VARCHAR2)
        RETURN DATE;

    --Added below procedure for change 2.0 to set the program last run time for Warehouse and sales channel
    PROCEDURE set_last_run_time (pn_warehouse_id IN NUMBER, pv_sales_channel IN VARCHAR2, pd_last_run_date IN DATE);

    --Begin CCR0008657
    FUNCTION get_vas_param_value (pn_header_id           IN NUMBER,
                                  pn_sold_to_org_id      IN NUMBER,
                                  pn_ship_to_org_id      IN NUMBER,
                                  pn_inventory_item_id   IN NUMBER := NULL,
                                  pv_parameter_name      IN VARCHAR)
        RETURN VARCHAR;

    FUNCTION get_order_attchments (p_order_number   IN NUMBER,
                                   p_category       IN VARCHAR2)
        RETURN VARCHAR2;

    --End CCR0008657

    --Added below procedure for change 2.0 to update orders by batch number
    PROCEDURE upd_batch_process_sts (p_batch_number    IN     NUMBER,
                                     p_from_status     IN     VARCHAR2,
                                     p_to_status       IN     VARCHAR2,
                                     x_update_status      OUT VARCHAR2,
                                     x_error_message      OUT VARCHAR2);

    --Added below procedure in Spec for change 2.0(Purge Program will call this procedure)
    PROCEDURE purge_archive (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_num_purge_days IN NUMBER
                             , p_in_num_purge_log_days IN NUMBER); --Added 2.2.

    --Added below procedure for change 2.0
    PROCEDURE upd_pick_tkt_proc_sts (p_order_number IN NUMBER, x_ret_sts OUT NUMBER, x_ret_message OUT VARCHAR2);

    --Procedure to update batch_number in Pick interface Headers table
    PROCEDURE proc_update_batch (pn_request_id IN NUMBER, pv_order_type IN VARCHAR2, x_update_status OUT NUMBER
                                 , x_error_message OUT VARCHAR2);

    --Added for change 2.0 --For Batching
    --This procedure picks up the batch number from the Pick Interface Header table and updates the batch number in all the staging tables
    PROCEDURE proc_upd_batch_num_child (pn_request_id IN NUMBER, pv_order_type IN VARCHAR2, x_update_status OUT NUMBER
                                        , x_error_message OUT VARCHAR2);

    --Procedure called by SOA to select eligible pick ticket batches with oracle object type as out variable
    PROCEDURE pick_tkt_extract_soa_obj_type (
        p_org_code        IN     VARCHAR2,                               --3.1
        x_batch_num_tbl      OUT xxd_ebs_hj_pick_tkt_batch_tbl);

    --Added get_sales_channel for change 2.1
    FUNCTION get_sales_channel (pn_order_header_id IN NUMBER)
        RETURN VARCHAR2;

    --Added below procedure for change 2.3
    PROCEDURE debug_prc (pv_application IN VARCHAR2, pv_debug_text IN VARCHAR2, pv_debug_message IN VARCHAR2, pn_created_by IN NUMBER, pn_session_id IN NUMBER, pn_debug_id IN NUMBER
                         , pn_request_id IN NUMBER);

    --Added below procedure for change 2.5
    PROCEDURE validate_crossdock_deliveries (
        pn_org_id          IN     NUMBER,
        pv_error_message      OUT VARCHAR2);
END xxd_wms_hj_int_pkg;
/


--
-- XXD_WMS_HJ_INT_PKG  (Synonym) 
--
--  Dependencies: 
--   XXD_WMS_HJ_INT_PKG (Package)
--
CREATE OR REPLACE SYNONYM SOA_INT.XXD_WMS_HJ_INT_PKG FOR APPS.XXD_WMS_HJ_INT_PKG
/


GRANT DEBUG ON APPS.XXD_WMS_HJ_INT_PKG TO APPSRO
/

GRANT EXECUTE, DEBUG ON APPS.XXD_WMS_HJ_INT_PKG TO SOA_INT
/

GRANT EXECUTE ON APPS.XXD_WMS_HJ_INT_PKG TO XXDO
/
