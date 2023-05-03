--
-- XXDO_CUSTACNOTIFY_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:15:39 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_CUSTACNOTIFY_PKG"
    AUTHID CURRENT_USER
AS
    p_conc_request_id     NUMBER;
    p_email               VARCHAR2 (1000);
    p_business_group_id   NUMBER;
    p_date_from           VARCHAR2 (20);
    p_date_to             VARCHAR2 (20);
    p_reprint             VARCHAR2 (3);
    p_customer_name       VARCHAR2 (240);

    /*function for submitting bursting program */
    FUNCTION submit_burst_request (p_code         IN VARCHAR2,
                                   p_request_id   IN NUMBER)
        RETURN NUMBER;

    FUNCTION beforereport
        RETURN BOOLEAN;

    FUNCTION afterreport
        RETURN BOOLEAN;
-- PROCEDURE build_where;

END xxdo_custacnotify_pkg;
/
