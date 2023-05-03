--
-- XXDO_NEG_ATP_ORD_RESCHED_PKG1  (Package) 
--
--  Dependencies: 
--   DO_MAIL_UTILS (Package)
--   FND_API (Package)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:16:38 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_NEG_ATP_ORD_RESCHED_PKG1"
AS
    -- ####################################################################################################################
    -- Package      : XXDO_NEG_ATP_ORD_RESCHED_PKG1
    -- Design       : This package will be used to find Negative ATP items and then Identify the
    --                corresponding sales order lines and try to reschedule them.
    --                If unable to reschedule the line, leave the line as is, do not update anything
    --
    -- Notes        :
    -- Modification :
    -- ----------
    -- Date            Name                Ver    Description
    -- ----------      --------------      -----  ------------------
    -- 29-Aug-2016    Kranthi Bollam       1.0    Initial Version
    -- 01-Dec-2016    Kranthi Bollam       1.1    Added a new procedure get_so_lines_by_brand and
    --                                            also added paramters to reschedule_api_call proc
    -- 22-Dec-2016    Kranthi Bollam       1.2    Added parameter 'Unschedule' and removed inv org
    --                                            parameters from schedule_orders procedure.
    --                                            Added parameter 'Unschedule' to reschedule_api_call
    --                                            and get_so_lines_by_brand procedures
    -- 27-Dec-2016    Kranthi Bollam       1.3    Brand wise program output has to be emailed to people
    --                                            in lookup "XXD_NEG_ATP_RESCHEDULE_EMAIL"
    -- 18-Dec-2018    Srinath Siricilla    1.4    Added New parameter to exclude the specific orders data
    --                                            based on parameters CCR0007642
    -- 18-Feb-2020    Tejaswi Gangumalla   1.5    Added new parameter for batch records and number of child threads
    -- 22-Feb-2021    Jayarajan A K        2.2    Modified for CCR0008870 - Global Inventory Allocation Project
    -- #########################################################################################################################

    --Global Variables declaration
    g_miss_num          CONSTANT NUMBER := apps.fnd_api.g_miss_num;
    g_miss_char         CONSTANT VARCHAR2 (1) := apps.fnd_api.g_miss_char;
    g_miss_date         CONSTANT DATE := apps.fnd_api.g_miss_date;
    g_ret_success       CONSTANT VARCHAR2 (1) := apps.fnd_api.g_ret_sts_success;
    g_ret_error         CONSTANT VARCHAR2 (1) := apps.fnd_api.g_ret_sts_error;
    g_ret_unexp_error   CONSTANT VARCHAR2 (1)
                                     := apps.fnd_api.g_ret_sts_unexp_error ;


    PROCEDURE schedule_orders (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, pn_inv_org_id1 IN NUMBER, --Start comment for change 1.2
                                                                                                    /*,pn_inv_org_id2        IN NUMBER
                                                                                                     ,pn_inv_org_id3        IN NUMBER
                                                                                                     ,pn_inv_org_id4        IN NUMBER
                                                                                                     ,pn_inv_org_id5        IN NUMBER
                                                                                                     ,pn_inv_org_id6        IN NUMBER
                                                                                                     ,pn_inv_org_id7        IN NUMBER
                                                                                                     ,pn_inv_org_id8        IN NUMBER
                                                                                                     ,pn_inv_org_id9        IN NUMBER
                                                                                                     ,pn_inv_org_id10       IN NUMBER*/
                                                                                                    pv_unschedule IN VARCHAR2, --End comment for change 1.2
                                                                                                                               pv_exclude IN VARCHAR2, -- Added for Change 1.4
                                                                                                                                                       pn_customer_id IN NUMBER, pv_request_date_from IN VARCHAR2, pv_request_date_to IN VARCHAR2, pv_brand IN VARCHAR2, pv_style IN VARCHAR2, pv_color IN VARCHAR2, pv_size IN VARCHAR2
                               , pn_retention_days IN NUMBER, pn_batch_records IN NUMBER, --Added for change 1.5
                                                                                          pn_threads IN NUMBER --Added for change 1.5
                                                                                                              );

    PROCEDURE reschedule_api_call (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, pn_batch_id IN NUMBER, pn_organization_id IN NUMBER, pv_brand IN VARCHAR2, pn_from_seq_num IN NUMBER
                                   , pn_to_seq_num IN NUMBER, pv_unschedule IN VARCHAR2, --Added for change 1.2
                                                                                         pv_exclude IN VARCHAR2); -- Added for Change 1.4

    PROCEDURE purge_data (pn_retention_days IN NUMBER DEFAULT 30);

    PROCEDURE write_log (pv_msg IN VARCHAR2);

    PROCEDURE audit_report (pn_batch_id IN NUMBER, pn_organization_id IN NUMBER, pv_brand IN VARCHAR2);

    PROCEDURE get_so_lines_by_brand (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, pn_batch_id IN NUMBER, pn_organization_id IN NUMBER, pv_brand IN VARCHAR2, pv_dblink IN VARCHAR2, pn_customer_id IN NUMBER, pv_request_date_from IN VARCHAR2, pv_request_date_to IN VARCHAR2, pv_unschedule IN VARCHAR2, --Added for change 1.2
                                                                                                                                                                                                                                                                                                         pv_exclude IN VARCHAR2, pn_batch_records IN NUMBER
                                     ,                  --Added for change 1.5
                                       pn_threads IN NUMBER --Added for change 1.5
                                                           ); -- Added for Change 1.4

    --Added email_output procedure for change 1.3
    PROCEDURE email_output (pn_batch_id IN NUMBER, pn_organization_id IN NUMBER, pv_brand IN VARCHAR2);

    --Added email_recipients function for change 1.3
    FUNCTION email_recipients (pv_lookup_type   IN VARCHAR2,
                               pv_inv_org       IN VARCHAR2)
        RETURN apps.do_mail_utils.tbl_recips;

    --Start changes v2.2
    FUNCTION get_sort_by_date (pn_line_id IN NUMBER)
        RETURN DATE;

    --End changes v2.2
    --Added below procedure purge_stg_data for change 2.4
    PROCEDURE purge_stg_data (errbuf OUT VARCHAR2, retcode OUT VARCHAR2);
END xxdo_neg_atp_ord_resched_pkg1;
/
