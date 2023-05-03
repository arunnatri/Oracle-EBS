--
-- XXDO_IEX_SCORING_PKG1  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:16:11 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_IEX_SCORING_PKG1"
AS
    PROCEDURE run_new_adl (p_errbuf OUT VARCHAR2, p_retcode OUT VARCHAR2, p_org_id IN NUMBER
                           , p_cust_account_id IN NUMBER);

    PROCEDURE POPULATE_ADL (p_org_id           IN NUMBER,
                            p_cust_acct_id     IN NUMBER,
                            p_brand            IN VARCHAR2,
                            p_account_number   IN VARCHAR2,
                            p_org_name         IN VARCHAR2);

    PROCEDURE INSERT_UPDATE (p_insert_update_flag   IN VARCHAR2,
                             p_cust_account_id      IN NUMBER,
                             p_org_id               IN NUMBER,
                             p_adl_q1               IN NUMBER DEFAULT NULL,
                             p_adl_q2               IN NUMBER DEFAULT NULL,
                             p_adl_q3               IN NUMBER DEFAULT NULL,
                             p_adl_q4               IN NUMBER DEFAULT NULL,
                             p_adl_q5               IN NUMBER DEFAULT NULL,
                             p_adl_q6               IN NUMBER DEFAULT NULL,
                             p_adl_q7               IN NUMBER DEFAULT NULL,
                             p_adl_q8               IN NUMBER DEFAULT NULL,
                             p_curr_adl             IN NUMBER DEFAULT NULL,
                             p_adl_variance         IN NUMBER DEFAULT NULL,
                             p_aging_bucket_score   IN NUMBER DEFAULT NULL,
                             p_aging_bucket         IN VARCHAR2 DEFAULT NULL,
                             p_booked_order_score   IN NUMBER DEFAULT NULL,
                             p_last_payment_score   IN NUMBER DEFAULT NULL,
                             p_adl_score            IN NUMBER DEFAULT NULL,
                             p_score                IN NUMBER DEFAULT NULL,
                             p_mapped_score         IN NUMBER DEFAULT NULL,
                             p_attribute_category   IN VARCHAR2 DEFAULT NULL,
                             p_attribute1           IN VARCHAR2 DEFAULT NULL,
                             p_attribute2           IN VARCHAR2 DEFAULT NULL,
                             p_attribute3           IN VARCHAR2 DEFAULT NULL,
                             p_attribute4           IN VARCHAR2 DEFAULT NULL,
                             p_attribute5           IN VARCHAR2 DEFAULT NULL,
                             p_attribute6           IN VARCHAR2 DEFAULT NULL,
                             p_attribute7           IN VARCHAR2 DEFAULT NULL,
                             p_attribute8           IN VARCHAR2 DEFAULT NULL,
                             p_attribute9           IN VARCHAR2 DEFAULT NULL,
                             p_attribute10          IN VARCHAR2 DEFAULT NULL,
                             p_attribute11          IN VARCHAR2 DEFAULT NULL,
                             p_attribute12          IN VARCHAR2 DEFAULT NULL,
                             p_attribute13          IN VARCHAR2 DEFAULT NULL,
                             p_attribute14          IN VARCHAR2 DEFAULT NULL,
                             p_attribute15          IN VARCHAR2 DEFAULT NULL,
                             p_attribute16          IN VARCHAR2 DEFAULT NULL,
                             p_attribute17          IN VARCHAR2 DEFAULT NULL,
                             p_attribute18          IN VARCHAR2 DEFAULT NULL,
                             p_attribute19          IN VARCHAR2 DEFAULT NULL,
                             p_attribute20          IN VARCHAR2 DEFAULT NULL);
END XXDO_IEX_SCORING_PKG1;
/
