--
-- XXDOAR_COMMON_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:12:10 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS.xxdoar_common_pkg
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
    --customer detail like account numnber,name and address
    FUNCTION get_cust_details (p_cust_id IN NUMBER, p_column IN VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION get_payment_det (p_id NUMBER, p_org_id NUMBER, p_col VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION get_terms (p_id NUMBER)
        RETURN VARCHAR2;

    FUNCTION get_collector (p_id NUMBER)
        RETURN VARCHAR2;

    FUNCTION get_ou_name (p_id NUMBER)
        RETURN VARCHAR2;

    FUNCTION get_type_name (p_id NUMBER, p_org_id NUMBER)
        RETURN VARCHAR2;

    -- This function wil get the cust detail for the specific site also
    FUNCTION get_cust_det (p_cust_id IN NUMBER, p_site_id IN NUMBER, p_org_id IN NUMBER
                           , p_column IN VARCHAR2)
        RETURN VARCHAR2;
END xxdoar_common_pkg;
/


--
-- XXDOAR_COMMON_PKG  (Synonym) 
--
--  Dependencies: 
--   XXDOAR_COMMON_PKG (Package)
--
CREATE OR REPLACE SYNONYM XXDO.XXDOAR_COMMON_PKG FOR APPS.XXDOAR_COMMON_PKG
/
