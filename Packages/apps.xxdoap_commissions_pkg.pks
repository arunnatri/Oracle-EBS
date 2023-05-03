--
-- XXDOAP_COMMISSIONS_PKG  (Package) 
--
--  Dependencies: 
--   AP_DISTRIBUTION_SETS (Synonym)
--   AP_INVOICES_ALL (Synonym)
--   AP_SUPPLIER_SITES (Synonym)
--   AP_TERMS_VL (View)
--   FND_APPLICATION (Synonym)
--   FND_CONCURRENT_REQUESTS (Synonym)
--   FND_FLEX_VALUES (Synonym)
--   FND_FLEX_VALUE_SETS (Synonym)
--   FND_GLOBAL (Package)
--   FND_RESPONSIBILITY (Synonym)
--   FND_USER (Synonym)
--   GL_LEDGERS (Synonym)
--   HR_LOCATIONS_ALL (Synonym)
--   HR_OPERATING_UNITS (View)
--   HZ_CUST_ACCOUNTS (Synonym)
--   HZ_CUST_ACCT_SITES (Synonym)
--   HZ_CUST_SITE_USES (Synonym)
--   HZ_PARTIES (Synonym)
--   PO_VENDORS (View)
--   PO_VENDOR_SITES (View)
--   RA_BATCH_SOURCES (Synonym)
--   RA_CUSTOMER_TRX (Synonym)
--   RA_TERMS (Synonym)
--   UTL_SMTP (Synonym)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:11:54 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDOAP_COMMISSIONS_PKG"
AS
    /***********************************************************************************
     *$header : *
     * *
     * AUTHORS : Venkata Nagalla *
     * *
     * PURPOSE : Commission Calculation and Creation - Deckers *
     * *
     * PARAMETERS : *
     * *
     * DATE : 1-Jun-2014 *
     * *
     * Assumptions : *
     * *
     * *
     * History *
     * Vsn Change Date Changed By Change Description *
     * ----- ----------- ------------------ ------------------------------------- *
     * 1.0 1-Jun-2014 Venkata Nagalla Initial Creation *
     * 1.2 10-Aug-2016 Infosys Function get_dist_gl_date for INC0308972-ENHC0012706
     *********************************************************************************/

    G_SOURCE_ORG_ID             hr_operating_units.organization_id%TYPE;
    G_TARGET_AP_ORG_ID          hr_operating_units.organization_id%TYPE;
    G_TARGET_AP_ORG_NAME        hr_operating_units.name%TYPE;
    G_TARGET_AR_ORG_ID          hr_operating_units.organization_id%TYPE;
    G_TARGET_AR_ORG_NAME        hr_operating_units.name%TYPE;
    G_TARGET_AR_CUSTOMER        hz_parties.party_name%TYPE;
    G_TARGET_AP_VENDOR          hz_parties.party_name%TYPE;
    G_TARGET_AP_VENDOR_SITE     ap_supplier_sites.vendor_site_code%TYPE;
    G_TARGET_AR_CUST_NUM        hz_cust_accounts.account_number%TYPE;
    G_TRX_CUTOFF_DATE           ap_invoices_all.creation_date%TYPE;
    G_SOURCE_TRX_TYPE           VARCHAR2 (30);
    G_EXCLUDE_SAMPLE_INVOICES   VARCHAR2 (1);
    G_RELATIONSHIP_VALUE_SET    fnd_flex_value_sets.flex_value_set_name%TYPE
                                    DEFAULT 'XXDO_COMMISSION_RELATIONSHIPS';
    G_COMMISSION_VALUE_SET      fnd_flex_value_sets.flex_value_set_name%TYPE
                                    DEFAULT 'XXDO_COMMISSION_PERCENTAGES';
    -- Start Changes V2.1
    G_BUYING_AGENT_OU_MAPPING   fnd_flex_value_sets.flex_value_set_name%TYPE
                                    DEFAULT 'XXDO_BUYING_AGENT_OU_MAPPING';
    G_TARGET_AR_CURRENCY        gl_ledgers.currency_code%TYPE DEFAULT 'USD';
    G_TARGET_AP_CURRENCY        gl_ledgers.currency_code%TYPE DEFAULT 'USD';
    --End Changes V2.1

    G_TARGET_CUSTOMER_ID        hz_cust_accounts.cust_account_id%TYPE;
    G_TARGET_CUSTOMER_SITE_ID   hz_cust_acct_sites.cust_acct_site_id%TYPE;
    G_TARGET_CUST_SITE_USE_ID   hz_cust_site_uses.site_use_id%TYPE;
    G_TARGET_VENDOR_ID          po_vendors.vendor_id%TYPE;
    G_TARGET_VENDOR_SITE_ID     po_vendor_sites.vendor_site_id%TYPE;
    G_RELATIONSHIP              fnd_flex_values.flex_value%TYPE;
    G_TARGET_AR_SOURCE          ra_batch_sources.NAME%TYPE; -- := 'Commissions';
    G_TARGET_DATE               DATE;
    G_TARGET_AP_SOB_ID          hr_operating_units.set_of_books_id%TYPE;
    G_TARGET_AR_SOB_ID          hr_operating_units.set_of_books_id%TYPE;
    G_TARGET_AR_TRX_NUM         ra_customer_trx.trx_number%TYPE;
    --G_TARGET_AR_TERMS_ID ra_terms.TERM_ID%TYPE DEFAULT 1037;--Commented by Madhav for DFCT0011041
    --G_TARGET_AP_TERMS_ID ra_terms.TERM_ID%TYPE DEFAULT 10003;--Commented by Madhav for DFCT0011041
    --G_TARGET_AP_PAY_METHOD ap_supplier_sites.PAYMENT_METHOD_LOOKUP_CODE%TYPE DEFAULT 'CHECK';--Commented by Madhav for DFCT0011041
    G_TARGET_AR_TERMS_ID        ra_terms.TERM_ID%TYPE; --Added by Madhav for DFCT0011041
    G_TARGET_AP_TERMS_ID        ap_terms_vl.TERM_ID%TYPE; --Added by Madhav for DFCT0011041
    G_TARGET_AP_PAY_METHOD      ap_supplier_sites.PAYMENT_METHOD_LOOKUP_CODE%TYPE; --Added by Madhav for DFCT0011041
    G_TARGET_AP_DIST_SET_ID     ap_distribution_sets.distribution_set_id%TYPE;
    G_TARGET_AP_SHIP_LOC_ID     hr_locations_all.location_id%TYPE;
    --G_TARGET_EXC_RATE_TYPE ra_customer_trx.EXCHANGE_RATE_TYPE%TYPE DEFAULT 'User';--Commented by Madhav for DFCT0011041
    G_TARGET_EXC_RATE_TYPE      ra_customer_trx.EXCHANGE_RATE_TYPE%TYPE
                                    DEFAULT 'Corporate'; --Added by Madhav for DFCT0011041
    --G_TARGET_EXC_RATE ra_customer_trx.EXCHANGE_RATE%TYPE DEFAULT 1; --Commented by Madhav for DFCT0011041
    G_TARGET_EXC_RATE           ra_customer_trx.EXCHANGE_RATE%TYPE
                                    DEFAULT NULL; --Added by Madhav for DFCT0011041
    G_TARGET_AR_REV_ACC_ID      hz_cust_site_uses.gl_id_rev%TYPE;
    G_AR_BASE_CURRENCY          gl_ledgers.currency_code%TYPE DEFAULT 'USD';
    --G_TARGET_AR_REC_ACC_ID hz_cust_site_uses.gl_id_rec%TYPE;
    G_RELATION_TRX_TYPE         VARCHAR2 (30);
    G_USER_ID                   fnd_user.user_id%TYPE := FND_GLOBAL.USER_ID;
    G_RESPONSIBILITY_ID         fnd_responsibility.responsibility_id%TYPE
                                    DEFAULT FND_GLOBAL.RESP_ID;
    G_RESP_APPL_ID              fnd_application.application_id%TYPE
                                    DEFAULT FND_GLOBAL.RESP_APPL_ID;
    G_CONC_REQUEST_ID           fnd_concurrent_requests.request_id%TYPE
                                    DEFAULT FND_GLOBAL.CONC_REQUEST_ID;

    c_global                    UTL_SMTP.connection := NULL;
    c_global_flag               NUMBER := 0;

    TYPE tbl_recips IS TABLE OF VARCHAR2 (240)
        INDEX BY BINARY_INTEGER;

    PROCEDURE SEND_MAIL (p_msg_from VARCHAR2, p_msg_to VARCHAR2, p_msg_subject VARCHAR2
                         , p_msg_text VARCHAR2);

    PROCEDURE SEND_MAIL (p_msg_from VARCHAR2, p_msg_to tbl_recips, p_msg_subject VARCHAR2
                         , p_msg_text VARCHAR2);

    PROCEDURE SEND_MAIL_HEADER (p_msg_from VARCHAR2, p_msg_to VARCHAR2, p_msg_subject VARCHAR2
                                , status OUT NUMBER);

    PROCEDURE SEND_MAIL_HEADER (p_msg_from VARCHAR2, p_msg_to tbl_recips, p_msg_subject VARCHAR2
                                , status OUT NUMBER);

    PROCEDURE SEND_MAIL_LINE (msg_text VARCHAR2, status OUT NUMBER);

    PROCEDURE SEND_MAIL_CLOSE (status OUT NUMBER);


    FUNCTION get_commission_perc (p_comm_date IN DATE)
        RETURN NUMBER;

    FUNCTION get_vendor_name (p_vendor_id IN NUMBER)
        RETURN VARCHAR2;

    FUNCTION get_site_code (p_vendor_site_id IN NUMBER)
        RETURN VARCHAR2;

    FUNCTION get_vendor_exclusion (p_vendor_id      IN NUMBER,
                                   p_invoice_type   IN VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION get_ven_site_exclusion (p_ven_site_id    IN NUMBER,
                                     p_invoice_type   IN VARCHAR2)
        RETURN VARCHAR2;

    PROCEDURE get_customer_det (p_customer_id IN NUMBER, x_customer_num OUT VARCHAR2, x_customer_name OUT VARCHAR2);

    FUNCTION get_po_line_creation_dt (p_invoice_id IN NUMBER)
        RETURN DATE;

    -- Function get_dist_gl_date Added by Infosys on 10-AUG-2016 for INC0308972-ENHC0012706 -- 1.2
    FUNCTION get_dist_gl_date (p_invoice_id    IN NUMBER,
                               pd_start_date      DATE,
                               pd_end_date        DATE)
        RETURN DATE;

    -- FUNCTION get_dist_amount Added by Deckers IT Team on 29-Apr-2017
    FUNCTION get_dist_amount (p_invoice_id    IN NUMBER,
                              pd_start_date      DATE,
                              pd_end_date        DATE)
        RETURN NUMBER;

    --Start changes by Deckers IT Team on 09-May-2017
    FUNCTION get_is_commissionable (pn_invoice_id NUMBER)
        RETURN CHAR;

    --End changes by Deckers IT Team on 09-May-2017

    FUNCTION get_po_date (p_invoice_id IN NUMBER)
        RETURN DATE;

    FUNCTION get_po_num (p_invoice_id IN NUMBER)
        RETURN VARCHAR2;


    FUNCTION get_brand (p_invoice_id IN NUMBER)
        RETURN VARCHAR2;

    FUNCTION get_commission_amt (p_invoice_id IN NUMBER)
        RETURN NUMBER;

    FUNCTION is_cust_site_setup (p_site_use_id IN NUMBER, x_term_id OUT NUMBER, x_rev_acc_id OUT NUMBER
                                 , x_ret_message OUT VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION is_supp_site_setup (p_supp_site_id IN NUMBER, x_term_id OUT NUMBER, x_pay_method_code OUT VARCHAR2
                                 , x_dist_set_id OUT NUMBER, x_ship_to_loc_id OUT NUMBER, x_ret_message OUT VARCHAR2)
        RETURN VARCHAR2;

    PROCEDURE get_target_details (x_target_ar_org_name OUT VARCHAR2, x_target_ap_org_name OUT VARCHAR2, x_customer_name OUT VARCHAR2
                                  , x_customer_number OUT VARCHAR2, x_tgt_vendor_name OUT VARCHAR2, x_tgt_site_code OUT VARCHAR2);


    PROCEDURE get_relation_details (p_src_org_id IN NUMBER, p_tgt_ap_org_id IN NUMBER, --Start Changes V2.1
                                                                                       --                                   p_tgt_ar_org_id   IN     NUMBER,
                                                                                       --End Changes V2.1
                                                                                       x_ret_code OUT VARCHAR2
                                    , x_ret_message OUT VARCHAR2);

    PROCEDURE create_target_ap_trx (x_ret_code      OUT VARCHAR2,
                                    x_ret_message   OUT VARCHAR2);

    PROCEDURE create_target_ar_trx (x_ret_code      OUT VARCHAR2,
                                    x_ret_message   OUT VARCHAR2);

    PROCEDURE commission_alert (errbuff        OUT VARCHAR2,
                                retcode        OUT VARCHAR2,
                                pn_ou_org   IN     NUMBER);

    FUNCTION get_email_recips (v_lookup_type VARCHAR2)
        RETURN XXDOAP_COMMISSIONS_PKG.tbl_recips;

    PROCEDURE load_src_trx (
        p_src_org_id           IN     NUMBER,
        p_src_trx_type         IN     VARCHAR2,
        p_src_trx_dt_from      IN     VARCHAR2,
        p_src_trx_dt_to        IN     VARCHAR2,
        p_src_invoice_id       IN     NUMBER DEFAULT NULL,
        p_src_vendor_id        IN     NUMBER DEFAULT NULL,
        p_src_vendor_site_id   IN     NUMBER DEFAULT NULL,
        p_gl_date_from         IN     VARCHAR2,               -- Added for 1.2
        p_gl_date_to           IN     VARCHAR2,               -- Added for 1.2
        x_ret_code                OUT VARCHAR2,
        x_ret_message             OUT VARCHAR2);

    PROCEDURE main (errbuf                 OUT VARCHAR2,
                    retcode                OUT VARCHAR2,
                    p_src_org_id        IN     NUMBER,
                    p_src_trx_type      IN     VARCHAR2,
                    p_src_trx_dt_from   IN     VARCHAR2,
                    p_src_trx_dt_to     IN     VARCHAR2,
                    p_src_trx_id        IN     NUMBER,
                    /* -- Start Changes V2.1
                    p_tgt_ar_org_id          IN     NUMBER,
                    p_tgt_customer_id        IN     NUMBER,
                    p_tgt_cust_site_use_id   IN     NUMBER,
                    p_tgt_ap_org_id          IN     NUMBER,
                    p_tgt_vendor_id          IN     NUMBER,
                    p_tgt_ven_site_id        IN     NUMBER,
                    End Changes V2.1*/
                    p_src_vendor_id     IN     NUMBER DEFAULT NULL,
                    p_src_ven_site_id   IN     NUMBER DEFAULT NULL,
                    p_tgt_trx_date      IN     VARCHAR2,
                    p_gl_date_from      IN     VARCHAR2,      -- Added for 1.2
                    p_gl_date_to        IN     VARCHAR2);     -- Added for 1.2
END XXDOAP_COMMISSIONS_PKG;
/
