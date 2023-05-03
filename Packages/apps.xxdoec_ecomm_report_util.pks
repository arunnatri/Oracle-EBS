--
-- XXDOEC_ECOMM_REPORT_UTIL  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:12:46 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDOEC_ECOMM_REPORT_UTIL"
IS
    -- Purpose: Briefly explain the functionality of the package
    -- Oracle apps custom reports, output file excel
    -- MODIFICATION HISTORY
    -- Person                                    Date                                Comments
    --Saritha  Movva                      03-06-2011                           Initial Version
    --Saritha Movva                       07-18-2011                       Phase3 Report Changes
    --Saritha Movva                       12-26-2011                       INC0099731  New Report for  Order reconciliation
    --Saritha Movva                       01-16-2012                       Added Site_ID Parameter to Order fill Rate, Booked orders, Unpaid Invoices, Warehouse Aging reports.
    --Saritha Movva                       01-24-2012                       New Report for Chanel Advisor  Cash reconciliation
    --Madhav Dhurjaty                     11-26-2012                       Added Default Null to in parameters of procedure ca_cash_recon_report for INC0127948
    --Madhav Dhurjaty                     03-15-2013                       Created new functions 'get_tracking_num', 'get_shipping_status' for DFCT0010413
    --Madhav Dhurjaty                     08-21-2013                       Modified run_margin_report for DFCT0010598
    -- BT Technology Team                 12-9-2014                        No Modification
    -- -----------------                   ------------------                --------------------------------------------------
    FUNCTION get_tracking_num (p_order_line_id IN NUMBER)
        --Created by Madhav Dhurjaty on 03/15/2013 for DFCT0010413
        RETURN VARCHAR2;

    FUNCTION get_shipping_status (p_order_line_id IN NUMBER)
        --Created by Madhav Dhurjaty on 03/15/2013 for DFCT0010413
        RETURN VARCHAR2;

    PROCEDURE run_atp_report (errbuf         OUT VARCHAR2,
                              retcode        OUT VARCHAR2,
                              p_brand            VARCHAR2,
                              p_sku_filter       VARCHAR2 DEFAULT NULL,
                              p_inv_org          NUMBER);

    PROCEDURE run_margin_report (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_org_id VARCHAR2, p_multi_org_ids VARCHAR2, p_date_from VARCHAR2, p_date_to VARCHAR2, p_brand VARCHAR2, p_margin NUMBER, p_customer_id NUMBER
                                 , p_dis_pro_code VARCHAR2);

    PROCEDURE run_unpaid_invoices_report (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_org_id VARCHAR2, p_site_id VARCHAR2, p_date_from VARCHAR2, p_date_to VARCHAR2
                                          , p_multi_org_ids VARCHAR2);

    PROCEDURE run_return_report (errbuf            OUT VARCHAR2,
                                 retcode           OUT VARCHAR2,
                                 p_org_id              VARCHAR2,
                                 p_multi_org_ids       VARCHAR2,
                                 p_date_from           VARCHAR2,
                                 p_date_to             VARCHAR2,
                                 p_brand               VARCHAR2,
                                 p_return_status       VARCHAR2);

    PROCEDURE run_warehouse_aging_report (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_org_id VARCHAR2, p_multi_org_ids VARCHAR2, p_site_id VARCHAR2, p_brand VARCHAR2
                                          , p_back_order VARCHAR2);

    PROCEDURE run_unapplied_cash_report (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_org_id VARCHAR2
                                         , p_multi_org_ids VARCHAR2);

    FUNCTION remove_special_characters (p_in_string VARCHAR2)
        RETURN VARCHAR2;

    PROCEDURE fillrate (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_brand VARCHAR2, p_year NUMBER, p_org_id NUMBER, p_multi_org_ids VARCHAR2
                        , p_site_id VARCHAR2);

    PROCEDURE credit_memo (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_date_from VARCHAR2, p_date_to VARCHAR2, p_org_id NUMBER, p_multi_org_ids VARCHAR2
                           , p_brand VARCHAR2);

    PROCEDURE orders_booking (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_org_id NUMBER, p_multi_org_ids VARCHAR2, p_site_id VARCHAR2, p_brand VARCHAR2, p_start_date VARCHAR2, p_end_date VARCHAR2, p_show_by VARCHAR2
                              , p_ignore_cancel_lines VARCHAR2-- Added  by Saritha Movva on 07/18/11 for Phase3 Report Changes
                                                              );

    PROCEDURE order_summary (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_org_id NUMBER, p_multi_org_ids VARCHAR2, p_start_date VARCHAR2, p_end_date VARCHAR2, p_brand VARCHAR2, p_invoice_start_date VARCHAR2, -- Added  by Saritha Movva on 07/18/11 for Phase3 Report Changes
                                                                                                                                                                                                                p_invoice_end_date VARCHAR2, p_state VARCHAR2, p_country VARCHAR2, p_inv_org_id NUMBER
                             , p_model VARCHAR2, p_back_ordered VARCHAR2);

    PROCEDURE shipped_not_invoiced (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_org_id NUMBER, p_multi_org_ids VARCHAR2, p_start_date VARCHAR2, p_end_date VARCHAR2
                                    , p_brand VARCHAR2);

    -- Added  by Saritha Movva on 07/18/11 for Phase3 Report Changes START
    PROCEDURE giftwrap (errbuf         OUT VARCHAR2,
                        retcode        OUT VARCHAR2,
                        p_org_id           NUMBER,
                        p_brand            VARCHAR2,
                        p_start_date       VARCHAR2,
                        p_end_date         VARCHAR2);

    PROCEDURE back_orders (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_org_id NUMBER, p_multi_org_ids VARCHAR2, p_brand VARCHAR2, p_start_date VARCHAR2
                           , p_end_date VARCHAR2, p_show_by VARCHAR2);

    PROCEDURE cancel_orders (errbuf            OUT VARCHAR2,
                             retcode           OUT VARCHAR2,
                             p_org_id              NUMBER,
                             p_multi_org_ids       VARCHAR2,
                             p_brand               VARCHAR2,
                             p_start_date          VARCHAR2,
                             p_end_date            VARCHAR2,
                             p_show_by             VARCHAR2,
                             p_cancel_reason       VARCHAR2);

    PROCEDURE outstanding_acc_bal (errbuf OUT VARCHAR2, retcode OUT VARCHAR2);

    PROCEDURE outof_stock (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_org_id NUMBER, p_inv_org NUMBER, p_brand VARCHAR2, p_sku VARCHAR2, p_item_category VARCHAR2, --Added by BT Technology Team on 19-FEB-2015
                                                                                                                                                                     p_atp_qty_min NUMBER, p_atp_qty_max NUMBER, p_atp_start_date VARCHAR2, p_atp_end_date VARCHAR2, p_back_order_qty_min NUMBER, p_back_order_qty_max NUMBER, p_back_order_start_date VARCHAR2, p_back_order_end_date VARCHAR2, p_pre_order_qty_min NUMBER, p_pre_order_qty_max NUMBER, p_pre_order_start_date VARCHAR2
                           , p_pre_order_end_date VARCHAR2, p_consumed_start_date VARCHAR2, p_consumed_end_date VARCHAR2--      ,
                                                                                                                        --      p_kco_qty_min                   NUMBER,                                 --Commented by BT Technology Team on 19-FEB-2015
                                                                                                                        --      p_kco_qty_max                   NUMBER                                  --Commented by BT Technology Team on 19-FEB-2015
                                                                                                                        );

    PROCEDURE orders_booking_na (errbuf                  OUT VARCHAR2,
                                 retcode                 OUT VARCHAR2,
                                 p_org_id                    NUMBER,
                                 p_multi_org_ids             VARCHAR2,
                                 p_site_id                   VARCHAR2,
                                 p_brand                     VARCHAR2,
                                 p_start_date                VARCHAR2,
                                 p_end_date                  VARCHAR2,
                                 p_sub_category              VARCHAR2,
                                 p_show_by                   VARCHAR2,
                                 p_ignore_cancel_lines       VARCHAR2);

    FUNCTION get_cancel_reason (p_line_id NUMBER, p_header_id NUMBER)
        RETURN VARCHAR2;

    PROCEDURE order_reconciliation_report (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_org_id VARCHAR2, p_multi_org_ids VARCHAR2, p_start_date VARCHAR2, p_end_date VARCHAR2
                                           , p_brand VARCHAR2);

    PROCEDURE ca_cash_recon_report (
        errbuf                OUT VARCHAR2,
        retcode               OUT VARCHAR2,
        p_site_id                 VARCHAR2,
        --p_settlement_id     VARCHAR2, --Commented by Madhav Dhurjaty for INC0127948
        --p_settlement_status VARCHAR2, --Commented by Madhav Dhurjaty for INC0127948
        --p_deposit_date_from VARCHAR2, --Commented by Madhav Dhurjaty for INC0127948
        --p_deposit_date_to   VARCHAR2  --Commented by Madhav Dhurjaty for INC0127948
        p_settlement_id           VARCHAR2 DEFAULT NULL,
        --Added by Madhav Dhurjaty for INC0127948
        p_settlement_status       VARCHAR2 DEFAULT NULL,
        --Added by Madhav Dhurjaty for INC0127948
        p_deposit_date_from       VARCHAR2 DEFAULT NULL,
        --Added by Madhav Dhurjaty for INC0127948
        p_deposit_date_to         VARCHAR2 DEFAULT NULL); --Added by Madhav Dhurjaty for INC0127948

    PROCEDURE manual_refunds_report (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_payment_date_from VARCHAR2
                                     , p_payment_date_to VARCHAR2);
END xxdoec_ecomm_report_util;
/


GRANT EXECUTE ON APPS.XXDOEC_ECOMM_REPORT_UTIL TO APPSRO
/
