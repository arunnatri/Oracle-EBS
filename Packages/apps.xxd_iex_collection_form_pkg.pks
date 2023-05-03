--
-- XXD_IEX_COLLECTION_FORM_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:21:14 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_IEX_COLLECTION_FORM_PKG"
AS
    -- #########################################################################################
    -- Author(s) : Tejaswi Gangumalla
    -- System    : Oracle Applications
    -- Subsystem :
    -- Schema    : APPS
    -- Purpose   : This package is used in collections form
    -- Dependency : None
    -- Change History
    -- --------------
    -- Date         Name                  Ver   Change               Description
    -- ----------   --------------        ----- -------------------- ---------------------
    -- 27-SEP-2021  Tejaswi Gangumalla    1.0   NA                   Initial Version
    --
    -- #########################################################################################
    PROCEDURE insert_party_data (pn_party_id          NUMBER,
                                 pn_cust_account_id   NUMBER,
                                 pn_org_id            NUMBER,
                                 pn_currency_code     VARCHAR2,
                                 pn_session_id        NUMBER);

    PROCEDURE insert_cust_account_data (pn_party_id          NUMBER,
                                        pn_cust_account_id   NUMBER,
                                        pn_org_id            NUMBER,
                                        pn_currency_code     VARCHAR2,
                                        pn_session_id        NUMBER);

    PROCEDURE insert_cust_account_sales_ytd_data (pn_party_id NUMBER, pn_cust_account_id NUMBER, pn_org_id NUMBER
                                                  , pn_currency_code VARCHAR2, pn_session_id NUMBER);

    PROCEDURE insert_cust_account_sales_prevytd_data (pn_party_id NUMBER, pn_cust_account_id NUMBER, pn_org_id NUMBER
                                                      , pn_currency_code VARCHAR2, pn_session_id NUMBER);

    PROCEDURE insert_cust_account_sales_prev_data (pn_party_id NUMBER, pn_cust_account_id NUMBER, pn_org_id NUMBER
                                                   , pn_currency_code VARCHAR2, pn_session_id NUMBER);

    PROCEDURE insert_cust_account_release_orders_data (pn_party_id NUMBER, pn_cust_account_id NUMBER, pn_org_id NUMBER
                                                       , pn_currency_code VARCHAR2, pn_session_id NUMBER);

    PROCEDURE insert_cust_account_release_orders21_data (pn_party_id NUMBER, pn_cust_account_id NUMBER, pn_org_id NUMBER
                                                         , pn_currency_code VARCHAR2, pn_session_id NUMBER);

    PROCEDURE insert_cust_account_order_value_data (pn_party_id NUMBER, pn_cust_account_id NUMBER, pn_org_id NUMBER
                                                    , pn_currency_code VARCHAR2, pn_session_id NUMBER);

    PROCEDURE insert_cust_account_ship_value_data (pn_party_id NUMBER, pn_cust_account_id NUMBER, pn_org_id NUMBER
                                                   , pn_currency_code VARCHAR2, pn_session_id NUMBER);

    PROCEDURE insert_cust_account_tot_order_value_data (pn_party_id NUMBER, pn_cust_account_id NUMBER, pn_org_id NUMBER
                                                        , pn_currency_code VARCHAR2, pn_session_id NUMBER);

    PROCEDURE insert_cust_account_tot_ship_value_data (pn_party_id NUMBER, pn_cust_account_id NUMBER, pn_org_id NUMBER
                                                       , pn_currency_code VARCHAR2, pn_session_id NUMBER);

    PROCEDURE submit_job (pn_party_id NUMBER, pn_cust_account_id NUMBER, pn_org_id NUMBER
                          , pn_currency_code VARCHAR2, pn_session_id NUMBER);

    PROCEDURE check_job_completion (pn_session_id     NUMBER,
                                    pn_party_id       NUMBER,
                                    pn_cust_acct_id   NUMBER);

    PROCEDURE purge_staging_tables (x_retcode      OUT NOCOPY VARCHAR2,
                                    x_errbuf       OUT NOCOPY VARCHAR2);
END;
/
