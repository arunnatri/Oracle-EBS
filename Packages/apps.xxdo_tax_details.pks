--
-- XXDO_TAX_DETAILS  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:17:53 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_TAX_DETAILS"
AS
    /***********************************************************************************
      *$header     :                                                                   *
      *                                                                                *
      * AUTHORS    :  Srinath Siricilla                                                *
      *                                                                                *
      * PURPOSE    :  Canada Tax Details Report - Deckers                                      *
      *                                                                                *
      * PARAMETERS :                                                                   *
      *                                                                                *
      * DATE       :  26-MAY-2017                                                      *
      *                                                                                *
      * Assumptions:                                                                   *
      *                                                                                *
      *                                                                                *
      * History                                                                        *
      * Vsn     Change Date  Changed By            Change Description                  *
      * -----   -----------  ------------------    ------------------------------------*
      * 1.0     26-MAY-2017  Srinath Siricilla     Initial Creation                    *
      *                                                                                *
      * 1.2     25-APR-2020  Arun N Murthy         For CCR0008587                      *                                                *
      *********************************************************************************/
    p_from_date   VARCHAR2 (100);
    p_to_date     VARCHAR2 (100);
    p_org_id      NUMBER;

    FUNCTION MAIN
        RETURN BOOLEAN;

    FUNCTION associated_Trx_number (pn_payment_schedule_id IN NUMBER)
        RETURN VARCHAR2;

    FUNCTION trx_ship_to_province (pn_ship_to_site_use_id   IN NUMBER,
                                   pn_org_id                IN NUMBER)
        RETURN VARCHAR2;

    FUNCTION trx_bill_to_province (pn_bill_to_site_use_id   IN NUMBER,
                                   pn_org_id                IN NUMBER)
        RETURN VARCHAR2;

    PROCEDURE insert_staging (cp_from_date   IN DATE,              --VARCHAR2,
                              cp_to_date     IN DATE,              --VARCHAR2,
                              cpn_org_id     IN NUMBER);

    FUNCTION get_lines_count (pn_customer_trx_id IN NUMBER)
        RETURN NUMBER;

    FUNCTION get_tax_amount (pn_receivable_application_id   IN NUMBER,
                             P_TAX_TYPE                        VARCHAR2)
        RETURN NUMBER;
END XXDO_TAX_DETAILS;
/
