--
-- XXD_AR_AGING_RPT_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:18:47 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_AR_AGING_RPT_PKG"
AS
    --  ####################################################################################################
    --  Package      : XXD_AR_AGING_RPT_PKG
    --  Design       : This package provides XML extract for Deckers Aging 4 Bucket by Brand Excel Report.
    --  Notes        :
    --  Modification :
    --  ======================================================================================
    --  Date            Version#   Name                    Comments
    --  ======================================================================================
    --  30-Mar-2021     1.0        Gaurav Joshi            Intial Version 1.0
    --  12-Dec-2022     1.1        Kishan Reddy            Added sales channel as parameter
    --  ####################################################################################################

    --
    -- To be used in query as bind variable
    --
    gn_error   CONSTANT NUMBER := 2;

    --   P_REPORTING_ENTITY_ID   VARCHAR2 (2000);
    --   P_AS_OF_DATE            VARCHAR2 (40);
    --   P_SUMMARY_LEVEL         VARCHAR2 (100);
    --   P_SHOW_RISK_AT_RISK     VARCHAR2 (100);
    --   P_FILE_PATH             VARCHAR2 (100);
    --   P_REPORTING_LEVEL       VARCHAR2 (100);
    --   P_BUCKET_TYPE           VARCHAR2 (100);
    --   P_CREDIT_OPTION         VARCHAR2 (100);
    --   P_CURR_CODE             VARCHAR2 (100);
    --   P_CALLED_FROM         VARCHAR2 (100);

    PROCEDURE main_wrapper (p_errbuf                   OUT VARCHAR2,
                            p_retcode                  OUT VARCHAR2,
                            p_reporting_entity_id   IN     VARCHAR2,
                            p_as_of_date            IN     VARCHAR2,
                            p_summary_level         IN     VARCHAR2,
                            p_credit_option         IN     VARCHAR2,
                            p_show_risk_at_risk     IN     VARCHAR2,
                            p_bucket_type           IN     VARCHAR2,
                            p_curr_code             IN     VARCHAR2,
                            p_file_path             IN     VARCHAR2,
                            p_sales_channel         IN     VARCHAR2);

    PROCEDURE generate_data (p_reporting_entity_id IN VARCHAR2, p_as_of_date IN VARCHAR2, p_summary_level IN VARCHAR2, p_credit_option IN VARCHAR2, p_show_risk_at_risk IN VARCHAR2, p_bucket_type IN VARCHAR2, p_curr_code IN VARCHAR2, p_file_path IN VARCHAR2, p_called_from IN VARCHAR2
                             , p_sales_channel IN VARCHAR2);

    FUNCTION c_main_formula (p_credit_option     IN VARCHAR2,
                             class               IN VARCHAR2,
                             TYPE                IN VARCHAR2,
                             p_risk_option       IN VARCHAR2,
                             amt_due_remaining   IN NUMBER,
                             amount_applied      IN NUMBER,
                             payment_sched_id    IN NUMBER,
                             p_as_of_date        IN DATE,
                             amount_credited     IN NUMBER,
                             amount_adjusted     IN NUMBER,
                             p_curr_code         IN VARCHAR2)
        RETURN NUMBER;

    FUNCTION c_cust_bal (p_credit_option IN VARCHAR2, p_risk_option IN VARCHAR2, class IN VARCHAR2, c_amt_due_remaining NUMBER, c_on_account_amount_cash NUMBER, c_on_account_amount_credit NUMBER
                         , c_on_account_amount_risk NUMBER)
        RETURN NUMBER;

    FUNCTION get_bucket_desc (pn_aging_bucket_id   IN NUMBER,
                              pn_bucket_seq_num    IN NUMBER)
        RETURN VARCHAR2;

    FUNCTION afterreport (p_called_from IN VARCHAR2)
        RETURN BOOLEAN;

    PROCEDURE print_log (pv_msg IN VARCHAR2);

    FUNCTION remove_junk (p_input IN VARCHAR2)
        RETURN VARCHAR2;
END XXD_AR_AGING_RPT_PKG;
/
