--
-- XXD_AR_AGING_ENHANCED_RPT_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:18:45 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_AR_AGING_ENHANCED_RPT_PKG"
AS
    --  ####################################################################################################
    --  Package      : XXD_AR_AGING_ENHANCED_RPT_PKG
    --  Design       : This package provides XML extract for Receivables Enhance Aging Report.
    --  Notes        :
    --  Modification :
    --  ======================================================================================
    --  Date            Version#   Name                    Comments
    --  ======================================================================================
    --  05-Apr-2017     1.0        Deckers IT Team          Intial Version 1.0
    --  27-Apr-2017     1.1        Prakash Vangari          CCR0006140
    --  23-Jan-2018     1.2        Infosys                  ENHC0013499 - CCR0006871
    --  05-Jun-2020     1.3       Showkath Ali             Updated for CCR0008685
    --  ####################################################################################################

    --
    -- To be used in query as bind variable
    --
    PN_REGION                  VARCHAR2 (500); -- Added by Infosys for ENHC0013499 - CCR0006871
    pn_operating_unit          VARCHAR2 (2000); -- Modified by Infosys for ENHC0013499 - CCR0006871
    PN_EX_ECOMM_OUS            VARCHAR2 (5); -- Added by Infosys for ENHC0013499 - CCR0006871
    pv_report_level            VARCHAR2 (100);
    pv_summary_level           VARCHAR2 (100);
    pv_as_of_date              VARCHAR2 (40);
    pn_aging_bucket_id         NUMBER;
    pv_brand                   VARCHAR2 (15);
    pn_collector_id            NUMBER;
    pv_summary_detail_level    VARCHAR2 (500);
    pv_include_disp_amt        VARCHAR2 (5);
    PV_SALES_CHANNEL           VARCHAR2 (100);                          -- 1.3
    PV_INC_EXC_SALES_CHANNEL   VARCHAR2 (100);                          -- 1.3



    -- CCR0006140
    FUNCTION get_bucket_desc (pn_aging_bucket_id   IN NUMBER,
                              pn_bucket_seq_num    IN NUMBER)
        RETURN VARCHAR2;

    -- CCR0006140

    FUNCTION remove_junk_characters (pv_msg_tx_in IN VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION return_credit_limit (pv_summary_detail_level VARCHAR2, pn_party_id NUMBER, pn_customer_id NUMBER)
        RETURN NUMBER;

    FUNCTION return_collector (pv_summary_detail_level VARCHAR2, pn_party_id NUMBER, pn_customer_id NUMBER)
        RETURN VARCHAR2;

    FUNCTION return_credit_analyst (pv_summary_detail_level VARCHAR2, pn_party_id NUMBER, pn_customer_id NUMBER)
        RETURN VARCHAR2;

    FUNCTION return_chargeback_analyst (pv_summary_detail_level VARCHAR2, pn_party_id NUMBER, pn_customer_id NUMBER)
        RETURN VARCHAR2;

    FUNCTION return_profile_class (pv_summary_detail_level VARCHAR2, pn_party_id NUMBER, pn_customer_id NUMBER)
        RETURN VARCHAR2;

    -- CCR0006140
    FUNCTION get_balance_due_as_of_date (p_applied_payment_schedule_id IN NUMBER, p_as_of_date IN DATE, p_class IN VARCHAR2
                                         , pn_operating_unit NUMBER)
        RETURN NUMBER;

    -- CCR0006140
    -- 1.3 changes start
    FUNCTION get_resource_number (p_resource_id   IN NUMBER,
                                  p_namenum       IN VARCHAR2)
        RETURN VARCHAR2;

    -- 1.3 changes end

    FUNCTION beforereport
        RETURN BOOLEAN;
END xxd_ar_aging_enhanced_rpt_pkg;
/
