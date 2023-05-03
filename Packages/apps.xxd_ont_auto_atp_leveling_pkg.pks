--
-- XXD_ONT_AUTO_ATP_LEVELING_PKG  (Package) 
--
--  Dependencies: 
--   FND_API (Package)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:22:33 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_ONT_AUTO_ATP_LEVELING_PKG"
AS
    -- ####################################################################################################################
    -- Package      : XXD_ONT_AUTOMATED_ATP_LVL_PKG
    -- Design       : This package will be used to find Negative ATP items and then Identify the
    --                corresponding sales order lines and try to reschedule safe move and at risk move.
    --
    -- Notes        :
    -- Modification :
    -- ----------
    -- Date            Name                Ver    Description
    -- ----------      --------------      -----  ------------------
    -- 04-Jun-2021    Shivanshu Talwar       1.0    Initial Version
    -- #########################################################################################################################

    --Global Variables declaration
    g_miss_num          CONSTANT NUMBER := apps.fnd_api.g_miss_num;
    g_miss_char         CONSTANT VARCHAR2 (1) := apps.fnd_api.g_miss_char;
    g_miss_date         CONSTANT DATE := apps.fnd_api.g_miss_date;
    g_ret_success       CONSTANT VARCHAR2 (1) := apps.fnd_api.g_ret_sts_success;
    g_ret_error         CONSTANT VARCHAR2 (1) := apps.fnd_api.g_ret_sts_error;
    g_ret_unexp_error   CONSTANT VARCHAR2 (1)
                                     := apps.fnd_api.g_ret_sts_unexp_error ;

    FUNCTION get_source_order_line_date (pn_order_header_id IN NUMBER, pn_order_line_id IN NUMBER, pv_date_type IN VARCHAR2)
        RETURN DATE;

    PROCEDURE email_output (pn_batch_id IN NUMBER, pn_organization_id IN NUMBER, pv_brand IN VARCHAR2);


    PROCEDURE audit_report (pn_batch_id IN NUMBER, pn_organization_id IN NUMBER, pv_brand IN VARCHAR2);



    PROCEDURE launch_worker_programs (pn_batch_id NUMBER, pn_organization_id NUMBER, pv_brand VARCHAR2, pn_batch_size NUMBER, pn_threads NUMBER, pv_processing_move VARCHAR2
                                      , pv_exclude VARCHAR2);

    PROCEDURE xxd_process_orders (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, pn_batch_id IN NUMBER, pn_organization_id IN NUMBER, pv_brand IN VARCHAR2, pn_from_seq_num IN NUMBER
                                  , pn_to_seq_num IN NUMBER, pv_order_move IN VARCHAR2, pv_exclude IN VARCHAR2);

    PROCEDURE truncate_staging_data (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, pn_purge_retention_days NUMBER);

    PROCEDURE main (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, pn_organization_id IN NUMBER, pv_Processing_Move IN VARCHAR2, pv_exclude IN VARCHAR2, pv_customer IN VARCHAR2, pd_request_date_from IN DATE, pd_request_date_to IN DATE, pv_brand IN VARCHAR2, pv_style IN VARCHAR2, pv_color IN VARCHAR2, pv_size IN VARCHAR2, pv_execution_mode IN VARCHAR2, pn_purge_retention_days IN NUMBER, pn_batch_size IN NUMBER
                    , pn_threads IN NUMBER, pv_debug IN VARCHAR2);

    --PROCEDURE purge_data (pn_retention_days IN NUMBER DEFAULT 30);

    PROCEDURE write_log (pv_msg IN VARCHAR2);
--Added email_output procedure for change 1.3
--PROCEDURE email_output (pn_batch_id          IN NUMBER,pn_organization_id   IN NUMBER,pv_brand             IN VARCHAR2);

--Added email_recipients function for change 1.3

END XXD_ONT_AUTO_ATP_LEVELING_PKG;
/
