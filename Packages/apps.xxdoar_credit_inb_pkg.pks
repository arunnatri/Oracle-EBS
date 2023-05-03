--
-- XXDOAR_CREDIT_INB_PKG  (Package) 
--
--  Dependencies: 
--   FND_API (Package)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:12:14 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDOAR_CREDIT_INB_PKG"
IS
    /**********************************************************************************************************
       file name    : xxdoar_credit_inb_pkg.pkb
       created on   : 11-FEB-2015
       created by   : Infosys
       purpose      : package specification used for the following
                              1. to record the credit review
     ***********************************************************************************************************
      Modification history:
     *****************************************************************************
         NAME:        xxdoar_credit_inb_pkg
         PURPOSE:

         REVISIONS:
         Version        Date        Author           Description
         ---------  ----------  ---------------  ------------------------------------
         1.0         11-FEB-2015     INFOSYS       1. Created this package Specification.
         1.1         06/04/2015    Infosys        Modified for QC defect 2137
    **********************************************************************
    ************************************************************************************************************/
    g_ret_success       VARCHAR2 (1) := fnd_api.g_ret_sts_success;
    g_ret_warn          VARCHAR2 (1) := 'W';
    g_ret_error         VARCHAR2 (1) := fnd_api.g_ret_sts_error;
    g_ret_unexp_error   VARCHAR2 (1) := fnd_api.g_ret_sts_unexp_error;

    /* PROCEDURE msg (pv_msg VARCHAR2, pn_level NUMBER := 1000); */
                                                          -- Commented for 1.1

    PROCEDURE create_credit_review (pv_retcode OUT NUMBER, pv_reterror OUT VARCHAR2, pv_customername VARCHAR2, pn_customernumber VARCHAR2, pn_creditscore NUMBER, pn_assignedcreditline NUMBER, pn_calculatedcreditline NUMBER, pn_confidencelevel NUMBER, pn_pqi NUMBER, pn_intelliscore NUMBER, pn_yearsinbusiness NUMBER, pv_nsf VARCHAR2, pv_altercode VARCHAR2, pv_manualreview VARCHAR2, pv_ownershipchagne NUMBER DEFAULT NULL, pv_rescorereason VARCHAR2 DEFAULT NULL, pv_scorename VARCHAR2 DEFAULT NULL, pd_scoredate DATE DEFAULT NULL, pv_agencyaccountid VARCHAR2 DEFAULT NULL, pv_accountid VARCHAR2 DEFAULT NULL, pv_companyid VARCHAR2 DEFAULT NULL
                                    , pv_scoreid VARCHAR2 DEFAULT NULL, pd_reviewdate DATE DEFAULT NULL, pv_agent VARCHAR2 DEFAULT NULL);

    PROCEDURE launch_approval_process (p_case_folder_id      IN     NUMBER,
                                       p_credit_request_id   IN     VARCHAR2,
                                       x_return_status          OUT VARCHAR2,
                                       x_message_count          OUT NUMBER,
                                       x_message_data           OUT VARCHAR2);

    PROCEDURE credit_handler (p_customer_name IN VARCHAR2, p_customer_number IN VARCHAR2, p_credit_score IN NUMBER, p_scoredate IN DATE, p_assigned_credit_line IN NUMBER, p_calculated_credit_line IN NUMBER, p_confidence_level IN NUMBER, p_payment_quality_index IN NUMBER, p_intelliscore IN NUMBER, p_years_in_business IN NUMBER, p_manual_review_flag IN VARCHAR2, p_nsf_c2b IN VARCHAR2, p_alert_code IN VARCHAR2, p_ownershipchange IN NUMBER, p_review_date IN DATE
                              , p_agent IN VARCHAR2, x_return_status OUT VARCHAR2, x_message_data OUT VARCHAR2);

    PROCEDURE create_credit_request (p_customer_name VARCHAR2, p_customer_number VARCHAR2, -- Added for 1.1
                                                                                           p_manual_review VARCHAR2, p_agent VARCHAR2, x_credit_request_id OUT NUMBER, p_assigned_credit_line IN NUMBER, x_party_id OUT NUMBER, x_return_status IN OUT VARCHAR2, x_message_count OUT NUMBER
                                     , x_message_data OUT VARCHAR2);

    PROCEDURE populate_case_folder (p_party_id IN NUMBER, p_credit_request_id IN NUMBER, x_case_folder_id OUT NUMBER, x_data_folder_id OUT NUMBER, x_return_status OUT VARCHAR2, x_message_count OUT NUMBER
                                    , x_message_data OUT VARCHAR2);

    PROCEDURE populate_case_folder_details (
        p_case_folder_id     IN     NUMBER,
        p_data_folder_id     IN     NUMBER,
        p_data_point_name    IN     VARCHAR2,
        p_data_point_value   IN     VARCHAR2 DEFAULT NULL,
        p_score              IN     VARCHAR2 DEFAULT NULL,
        x_return_status         OUT VARCHAR2,
        x_message_count         OUT NUMBER,
        x_message_data          OUT VARCHAR2);

    PROCEDURE implement_recommendations (p_case_folder_id IN NUMBER, p_customer_number IN VARCHAR2, p_reviewdate IN DATE, p_credit_request_id IN VARCHAR2, p_scoredate DATE, p_credit_score IN NUMBER, p_agent IN VARCHAR2, p_assigned_credit_line IN NUMBER, p_calculated_credit_line IN NUMBER
                                         , x_return_status OUT VARCHAR2, x_message_count OUT NUMBER, x_message_data OUT VARCHAR2);

    PROCEDURE initiate_manual_review (p_case_folder_id IN NUMBER, p_credit_request_id IN VARCHAR2, p_agent IN VARCHAR2
                                      , x_return_status OUT VARCHAR2, x_message_count OUT NUMBER, x_message_data OUT VARCHAR2);
END;
/


GRANT EXECUTE ON APPS.XXDOAR_CREDIT_INB_PKG TO SOA_INT
/
