--
-- XXDOAR_COMMON_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:41:22 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS.xxdoar_common_pkg
AS
    /******************************************************************************
       NAME:       XXDOAR_COMMON_PKG
       PURPOSE:   To define common AR functions

       REVISIONS:
       Ver        Date        Author           Description
       ---------  ----------  ---------------  ------------------------------------
       1.0        11/23/2010     Shibu        1. Created this package for AR general fetch
       1.1        10/23/2014     BT Team   Changes for BT
    ******************************************************************************/

    /*  This PROCEDURE is used to get the  customer credit limit and balance info*/

    -- This function return the customer name,number and address information
    -- Pass p_coulumn  parameter with the below listed value to get the data
    /*     address1         =     ADD1
           address2         =     ADD2
           address3         =     ADD3
           address4         =     ADD4
           city             =     CITY
           state            =     STATE
           postal_code      =     ZIP
           country          =     COUNTRY
           account_number   =     ACCNUM
           party_name       =     PNAME   */
    FUNCTION get_cust_details (p_cust_id IN NUMBER, p_column IN VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_address1         apps.hz_locations.address1%TYPE;
        lv_address2         apps.hz_locations.address2%TYPE;
        lv_address3         apps.hz_locations.address3%TYPE;
        lv_address4         apps.hz_locations.address4%TYPE;
        lv_city             apps.hz_locations.city%TYPE;
        lv_state            apps.hz_locations.state%TYPE;
        lv_postal_code      apps.hz_locations.postal_code%TYPE;
        lv_country          apps.hz_locations.country%TYPE;
        lv_account_number   apps.hz_cust_accounts.account_number%TYPE;
        lv_party_name       apps.hz_parties.party_name%TYPE;
        lv_return           VARCHAR2 (100);
    BEGIN
        SELECT loc.address1, loc.address2, loc.address3,
               loc.address4, loc.city, loc.state,
               loc.postal_code, loc.country, cust_acct.account_number,
               party.party_name
          INTO lv_address1, lv_address2, lv_address3, lv_address4,
                          lv_city, lv_state, lv_postal_code,
                          lv_country, lv_account_number, lv_party_name
          FROM apps.hz_party_sites psites, apps.hz_locations loc, apps.hz_cust_acct_sites_all sites,
               apps.hz_cust_site_uses_all uses, apps.hz_cust_accounts cust_acct, apps.hz_parties party
         WHERE     sites.party_site_id = psites.party_site_id
               AND loc.location_id = psites.location_id
               AND sites.cust_account_id = p_cust_id
               AND sites.cust_acct_site_id = uses.cust_acct_site_id
               AND uses.primary_flag = 'Y'
               AND uses.site_use_code = 'BILL_TO'
               AND sites.cust_account_id = cust_acct.cust_account_id
               AND cust_acct.party_id = party.party_id
               AND ROWNUM = 1;

        IF p_column = 'ADD1'
        THEN
            lv_return   := lv_address1;
        ELSIF p_column = 'ADD2'
        THEN
            lv_return   := lv_address2;
        ELSIF p_column = 'ADD3'
        THEN
            lv_return   := lv_address3;
        ELSIF p_column = 'ADD4'
        THEN
            lv_return   := lv_address4;
        ELSIF p_column = 'CITY'
        THEN
            lv_return   := lv_city;
        ELSIF p_column = 'STATE'
        THEN
            lv_return   := lv_state;
        ELSIF p_column = 'ZIP'
        THEN
            lv_return   := lv_postal_code;
        ELSIF p_column = 'COUNTRY'
        THEN
            lv_return   := lv_country;
        ELSIF p_column = 'ACCNUM'
        THEN
            lv_return   := lv_account_number;
        ELSIF p_column = 'PNAME'
        THEN
            lv_return   := lv_party_name;
        END IF;

        RETURN (lv_return);
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            RETURN (NULL);
        WHEN OTHERS
        THEN
            RETURN (NULL);
    END get_cust_details;

    -- Payment Number and Description
    FUNCTION get_payment_det (p_id NUMBER, p_org_id NUMBER, p_col VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_salesrep_number   VARCHAR2 (40) := NULL;
        lv_salesrep_name     VARCHAR2 (240) := NULL;
        l_return             VARCHAR2 (240) := NULL;
    BEGIN
        SELECT rep.salesrep_number, rep.NAME AS salesrep_name
          INTO lv_salesrep_number, lv_salesrep_name
          FROM jtf.jtf_rs_salesreps rep
         WHERE rep.salesrep_id = p_id AND rep.org_id = p_org_id;

        IF p_col = 'SNUM'
        THEN
            l_return   := lv_salesrep_number;
        ELSIF p_col = 'SNAME'
        THEN
            l_return   := lv_salesrep_name;
        END IF;

        RETURN (l_return);
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            lv_salesrep_number   := NULL;
            lv_salesrep_name     := NULL;
            RETURN NULL;
        WHEN OTHERS
        THEN
            lv_salesrep_number   := NULL;
            lv_salesrep_name     := NULL;
            RETURN NULL;
    END get_payment_det;

    --Payment terms
    FUNCTION get_terms (p_id NUMBER)
        RETURN VARCHAR2
    IS
        lv_payment_terms   VARCHAR2 (240) := NULL;
    BEGIN
        SELECT pt.description
          INTO lv_payment_terms
          FROM apps.ra_terms_tl pt
         WHERE pt.term_id = p_id AND pt.LANGUAGE = USERENV ('LANG');

        RETURN (lv_payment_terms);
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            lv_payment_terms   := NULL;
            RETURN NULL;
        WHEN OTHERS
        THEN
            lv_payment_terms   := NULL;
            RETURN NULL;
    END get_terms;

    FUNCTION get_collector (p_id NUMBER)
        RETURN VARCHAR2
    IS
        lv_collector   VARCHAR2 (240) := NULL;
    BEGIN
        SELECT NVL (coll.NAME, 'NO COLLECTOR') collector
          INTO lv_collector
          FROM apps.hz_customer_profiles hzp, apps.ar_collectors coll
         WHERE     hzp.cust_account_id = p_id
               AND hzp.status = 'A'
               AND hzp.site_use_id IS NULL
               AND hzp.collector_id = coll.collector_id;

        RETURN (lv_collector);
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            lv_collector   := NULL;
            RETURN NULL;
        WHEN OTHERS
        THEN
            lv_collector   := NULL;
            RETURN NULL;
    END get_collector;

    FUNCTION get_ou_name (p_id NUMBER)
        RETURN VARCHAR2
    IS
        lv_ou_name   VARCHAR2 (240) := NULL;
    BEGIN
        SELECT NAME
          INTO lv_ou_name
          FROM apps.hr_operating_units
         WHERE organization_id = p_id;

        RETURN (lv_ou_name);
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            lv_ou_name   := NULL;
            RETURN NULL;
        WHEN OTHERS
        THEN
            lv_ou_name   := NULL;
            RETURN NULL;
    END get_ou_name;

    FUNCTION get_type_name (p_id NUMBER, p_org_id NUMBER)
        RETURN VARCHAR2
    IS
        lv_type_name   VARCHAR2 (240) := NULL;
    BEGIN
        SELECT NAME type_name
          INTO lv_type_name
          FROM apps.ra_cust_trx_types_all trx_types
         WHERE     trx_types.org_id = p_org_id
               AND trx_types.cust_trx_type_id = p_id;

        RETURN (lv_type_name);
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            lv_type_name   := NULL;
            RETURN NULL;
        WHEN OTHERS
        THEN
            lv_type_name   := NULL;
            RETURN NULL;
    END get_type_name;

    FUNCTION get_cust_det (p_cust_id IN NUMBER, p_site_id IN NUMBER, p_org_id IN NUMBER
                           , p_column IN VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_address1         apps.hz_locations.address1%TYPE;
        lv_address2         apps.hz_locations.address2%TYPE;
        lv_address3         apps.hz_locations.address3%TYPE;
        lv_address4         apps.hz_locations.address4%TYPE;
        lv_city             apps.hz_locations.city%TYPE;
        lv_state            apps.hz_locations.state%TYPE;
        lv_postal_code      apps.hz_locations.postal_code%TYPE;
        lv_country          apps.hz_locations.country%TYPE;
        lv_account_number   apps.hz_cust_accounts.account_number%TYPE;
        lv_party_name       apps.hz_parties.party_name%TYPE;
        lv_return           VARCHAR2 (100);
    BEGIN
        SELECT loc.address1, loc.address2, loc.address3,
               loc.address4, loc.city, loc.state,
               loc.postal_code, loc.country, cust_acct.account_number,
               party.party_name
          INTO lv_address1, lv_address2, lv_address3, lv_address4,
                          lv_city, lv_state, lv_postal_code,
                          lv_country, lv_account_number, lv_party_name
          FROM apps.hz_party_sites psites, apps.hz_locations loc, apps.hz_cust_acct_sites_all sites,
               apps.hz_cust_site_uses_all uses, apps.hz_cust_accounts cust_acct, apps.hz_parties party
         WHERE     sites.party_site_id = psites.party_site_id
               AND loc.location_id = psites.location_id
               AND sites.cust_account_id = p_cust_id
               AND sites.cust_acct_site_id = uses.cust_acct_site_id
               AND uses.site_use_id = NVL (p_site_id, uses.site_use_id)
               AND uses.org_id = p_org_id
               AND uses.primary_flag = 'Y'
               AND uses.site_use_code = 'BILL_TO'
               AND sites.cust_account_id = cust_acct.cust_account_id
               AND cust_acct.party_id = party.party_id;

        IF p_column = 'ADD1'
        THEN
            lv_return   := lv_address1;
        ELSIF p_column = 'ADD2'
        THEN
            lv_return   := lv_address2;
        ELSIF p_column = 'ADD3'
        THEN
            lv_return   := lv_address3;
        ELSIF p_column = 'ADD4'
        THEN
            lv_return   := lv_address4;
        ELSIF p_column = 'CITY'
        THEN
            lv_return   := lv_city;
        ELSIF p_column = 'STATE'
        THEN
            lv_return   := lv_state;
        ELSIF p_column = 'ZIP'
        THEN
            lv_return   := lv_postal_code;
        ELSIF p_column = 'COUNTRY'
        THEN
            lv_return   := lv_country;
        ELSIF p_column = 'ACCNUM'
        THEN
            lv_return   := lv_account_number;
        ELSIF p_column = 'PNAME'
        THEN
            lv_return   := lv_party_name;
        END IF;

        RETURN (lv_return);
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            RETURN (NULL);
        WHEN OTHERS
        THEN
            RETURN (NULL);
    END get_cust_det;
END xxdoar_common_pkg;
/


--
-- XXDOAR_COMMON_PKG  (Synonym) 
--
CREATE OR REPLACE SYNONYM XXDO.XXDOAR_COMMON_PKG FOR APPS.XXDOAR_COMMON_PKG
/
