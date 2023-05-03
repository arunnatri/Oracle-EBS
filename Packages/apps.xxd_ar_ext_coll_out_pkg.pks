--
-- XXD_AR_EXT_COLL_OUT_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:19:00 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_AR_EXT_COLL_OUT_PKG"
IS
    /***************************************************************************************
    * Program Name : XXD_AR_EXT_COLL_OUT_PKG                                                *
    * Language     : PL/SQL                                                                *
    * Description  : Package to generate xml file for iCollector integration               *
    *                                                                                      *
    * History      :                                                                       *
    *                                                                                      *
    * WHO          :       WHAT      Desc                                    WHEN          *
    * -------------- ----------------------------------------------------------------------*
    * Kishan Reddy         1.0       Initial Version                         16-JUL-2022   *
    * -------------------------------------------------------------------------------------*/
    PROCEDURE createxml (p_conc_request_id   IN NUMBER,
                         p_dir_name          IN VARCHAR2,
                         p_file_name         IN VARCHAR2);

    FUNCTION get_last_payment_amt (p_party_id IN NUMBER)
        RETURN NUMBER;

    FUNCTION get_last_payment_date (p_party_id IN NUMBER)
        RETURN DATE;

    FUNCTION get_last_payment_due_date (p_party_id IN NUMBER)
        RETURN DATE;

    FUNCTION get_claim_owner (p_claim_id IN NUMBER)
        RETURN VARCHAR2;

    FUNCTION get_country (p_org_id IN NUMBER)
        RETURN VARCHAR2;


    FUNCTION get_currency (p_org_id IN NUMBER)
        RETURN VARCHAR2;

    FUNCTION get_language (p_customer_id IN NUMBER, p_bill_to_site_use_id IN NUMBER, p_org_id IN NUMBER
                           , p_party_id IN NUMBER)
        RETURN VARCHAR2;

    FUNCTION return_credit_limit (pn_party_id        NUMBER,
                                  pv_currency_code   VARCHAR2)
        RETURN NUMBER;

    FUNCTION return_last_credit_date (pn_party_id        NUMBER,
                                      pv_currency_code   VARCHAR2)
        RETURN DATE;

    FUNCTION return_next_credit_date (pn_party_id        NUMBER,
                                      pv_currency_code   VARCHAR2)
        RETURN DATE;

    FUNCTION return_profile_class (pn_party_id NUMBER)
        RETURN VARCHAR2;

    FUNCTION return_credit_analyst (pn_party_id NUMBER)
        RETURN VARCHAR2;

    FUNCTION return_deduction_reseacher (pn_party_id NUMBER)
        RETURN VARCHAR2;

    FUNCTION return_collector (pn_party_id NUMBER)
        RETURN VARCHAR2;

    FUNCTION get_profile_currency (pn_party_id        NUMBER,
                                   pv_currency_code   VARCHAR2)
        RETURN VARCHAR;

    FUNCTION get_sales_resp (pn_salesrep_id NUMBER)
        RETURN VARCHAR2;

    PROCEDURE insert_open_ar_staging (p_org_id IN NUMBER, x_ret_code OUT VARCHAR2, x_ret_message OUT VARCHAR2);

    PROCEDURE main (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_org_id IN NUMBER
                    , p_file_path IN VARCHAR2);
END XXD_AR_EXT_COLL_OUT_PKG;
/
